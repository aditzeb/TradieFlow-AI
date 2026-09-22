const { test, before, beforeEach, after } = require("node:test");
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { resolve } = require("node:path");
const { initializeTestEnvironment, assertSucceeds, assertFails } = require("@firebase/rules-unit-testing");
const { doc, setDoc, getDoc, updateDoc, deleteDoc, collection, query, where, orderBy, getDocs, serverTimestamp, Timestamp } = require("firebase/firestore");
const { ref, uploadBytes, getBytes, getMetadata, updateMetadata, deleteObject } = require("firebase/storage");
const { deleteApp } = require("firebase-admin/app");
const { getFirestore, Timestamp: AdminTimestamp } = require("firebase-admin/firestore");
const triage = require("../lib/triage");

const projectId = "demo-tradieflow-ai";
const bucket = "gs://tradieflow-ai.firebasestorage.app";
const png = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=", "base64");
let env;
let app;
let db;
const data = (id, ownerId = "owner") => ({
  id, ownerId, createdAt: serverTimestamp(), status: "RECEIVED",
  customer: { suburb: "Balmain", state: "NSW", postcode: "2041" },
  description: "No hot water", media: { storagePath: `jobs/${id}/photo.jpg` },
});
const firestore = (uid = "owner", claims = {}) => env.authenticatedContext(uid, claims).firestore();
const storage = (uid = "owner", claims = {}) => env.authenticatedContext(uid, claims).storage(bucket);
const photo = (id, uid = "owner", claims = {}) => ref(storage(uid, claims), `jobs/${id}/photo.jpg`);
const metadata = (ownerId = "owner", contentType = "image/png") => ({ contentType, customMetadata: { ownerId } });
const result = {
  urgency: "P3_ROUTINE", urgencyReasoning: "Licensed inspection required.", hazardIdentified: false,
  immediateSafetyAction: "Advisory only; contact a licensed tradesperson.",
  appliance: { brand: "Unknown", modelNumber: "Unreadable", type: "Unknown", estimatedAgeBracket: "Unknown" },
  faultDiagnostic: "Unconfirmed diagnosis.", recommendedParts: [], estimatedLaborHours: 0.5,
  quoteAud: { calloutFee: 100, laborCost: 0, partsCost: 0, gst: 10, totalEstimate: 110 },
  dynamicClarification: "Can you provide a clearer label photo?",
};
const usageRefs = (day = new Date().toISOString().slice(0, 10), ownerId = "owner") => {
  const globalRef = db.doc(`_triageUsage/${day}`);
  return [globalRef, globalRef.collection("owners").doc(Buffer.from(ownerId).toString("base64url"))];
};

before(async () => {
  assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? "", /^(127\.0\.0\.1|localhost):8080$/);
  assert.match(process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? "", /^(127\.0\.0\.1|localhost):9199$/);
  env = await initializeTestEnvironment({
    projectId,
    firestore: { rules: readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8") },
    storage: { rules: readFileSync(resolve(__dirname, "../../storage.rules"), "utf8") },
  });
  process.env.GCLOUD_PROJECT = projectId;
  process.env.OPENROUTER_API_KEY = "emulator-test-key";
  require("../lib/index");
  app = require("firebase-admin/app").getApp();
  db = getFirestore(app);
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env?.cleanup();
  if (app) await deleteApp(app);
});

test("Firestore exact owner-create contract and Australian location validation", async () => {
  const ownerDb = firestore();
  await assertSucceeds(setDoc(doc(ownerDb, "triageJobs", "valid-job"), data("valid-job")));
  const invalid = [
    { status: "ANALYZING" }, { ownerId: "someone-else" }, { id: "different-id" },
    { aiAnalysis: {} }, { error: "fake" }, { createdAt: Timestamp.fromMillis(0) },
    { analysisStartedAt: serverTimestamp() }, { analysisAttempts: 1 },
    { customer: { suburb: " Balmain ", state: "NSW", postcode: "2041" } },
    { customer: { suburb: " ", state: "NSW", postcode: "2041" } },
    { customer: { suburb: "A\nB", state: "NSW", postcode: "2041" } },
    { customer: { suburb: "A\nB\nC", state: "NSW", postcode: "2041" } },
    { customer: { suburb: "A\u0085B", state: "NSW", postcode: "2041" } },
    { customer: { suburb: "Balmain", state: "ZZ", postcode: "2041" } },
    { customer: { suburb: "Balmain", state: "NSW", postcode: "2600" } },
    { customer: { suburb: "Balmain", state: "NSW", postcode: "0000" } },
    { customer: { suburb: "Balmain", state: "NSW", postcode: 2041 } },
    { customer: { suburb: "Balmain", state: "NSW", postcode: "2041", extra: true } },
    { description: "x".repeat(4001) }, { description: 123 },
    { media: { storagePath: "jobs/other/photo.jpg" } },
    { media: { storagePath: "jobs/test/photo.jpg", extra: true } },
  ];
  for (const [index, patch] of invalid.entries()) {
    const id = `invalid-${index}`;
    await assertFails(setDoc(doc(ownerDb, "triageJobs", id), { ...data(id), ...patch }));
  }
  for (const key of Object.keys(data("missing"))) {
    const id = `missing-${key}`;
    const value = data(id);
    delete value[key];
    await assertFails(setDoc(doc(ownerDb, "triageJobs", id), value));
  }
  for (const [state, postcode] of [["ACT", "0200"], ["NT", "0800"], ["VIC", "3000"], ["QLD", "4000"], ["SA", "5000"], ["WA", "6000"], ["TAS", "7000"]]) {
    const id = `state-${state}`;
    await assertSucceeds(setDoc(doc(ownerDb, "triageJobs", id), { ...data(id), customer: { suburb: "Test", state, postcode } }));
  }
  await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), "triageJobs", "anonymous"), data("anonymous")));
  await assertFails(setDoc(doc(ownerDb, "elsewhere", "denied"), data("denied")));
});

test("owners read only their jobs; dispatcher boolean claim permits collection-wide reads", async () => {
  const id = "read-permissions";
  await setDoc(doc(firestore(), "triageJobs", id), data(id));
  await assertSucceeds(getDoc(doc(firestore(), "triageJobs", id)));
  await assertFails(getDoc(doc(firestore("stranger"), "triageJobs", id)));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), "triageJobs", id)));
  await assertFails(getDoc(doc(firestore("fake-dispatcher", { dispatcher: "true" }), "triageJobs", id)));
  await assertSucceeds(getDoc(doc(firestore("dispatcher", { dispatcher: true }), "triageJobs", id)));
  await assertSucceeds(getDocs(query(collection(firestore(), "triageJobs"), where("ownerId", "==", "owner"), orderBy("createdAt", "desc"))));
  await assertFails(getDocs(query(collection(firestore(), "triageJobs"), orderBy("createdAt", "desc"))));
  await assertSucceeds(getDocs(query(collection(firestore("dispatcher", { dispatcher: true }), "triageJobs"), orderBy("createdAt", "desc"))));
  for (const client of [firestore(), firestore("stranger"), firestore("dispatcher", { dispatcher: true })]) {
    await assertFails(updateDoc(doc(client, "triageJobs", id), { status: "TRIAGED" }));
    await assertFails(deleteDoc(doc(client, "triageJobs", id)));
  }
});

test("Storage immutable owner uploads, MIME, metadata and 5 MiB boundaries", async () => {
  await assertSucceeds(uploadBytes(photo("photo-owner"), png, metadata()));
  await assertFails(uploadBytes(photo("photo-owner"), png, metadata()));
  await assertFails(uploadBytes(photo("photo-owner", "stranger"), png, metadata("stranger")));
  await assertFails(updateMetadata(photo("photo-owner"), { customMetadata: { ownerId: "stranger" } }));
  await assertFails(uploadBytes(photo("spoof-owner"), png, metadata("stranger")));
  await assertFails(uploadBytes(photo("missing-owner"), png, { contentType: "image/png" }));
  await assertFails(uploadBytes(photo("bad-type"), png, metadata("owner", "image/gif")));
  await assertFails(uploadBytes(photo("empty"), Buffer.alloc(0), metadata()));
  await assertFails(uploadBytes(photo("oversized"), Buffer.alloc(5 * 1024 * 1024 + 1), metadata()));
  await assertSucceeds(uploadBytes(photo("max-sized"), Buffer.alloc(5 * 1024 * 1024), metadata()));
  await assertSucceeds(uploadBytes(photo("jpeg-type"), png, metadata("owner", "image/jpeg")));
  await assertSucceeds(uploadBytes(photo("webp-type"), png, metadata("owner", "image/webp")));
  await assertFails(uploadBytes(ref(storage(), "jobs/wrong/photo.png"), png, metadata()));
  await assertFails(uploadBytes(ref(storage(), "jobs/wrong/extra/photo.jpg"), png, metadata()));
  await assertFails(uploadBytes(ref(env.unauthenticatedContext().storage(bucket), "jobs/unauth/photo.jpg"), png, metadata()));
});

test("Storage reads require owner/dispatcher and cleanup requires owner plus absent job", async () => {
  const id = "storage-read-cleanup";
  await uploadBytes(photo(id), png, metadata());
  await assertSucceeds(getBytes(photo(id)));
  await assertSucceeds(getBytes(photo(id, "dispatcher", { dispatcher: true })));
  await assertFails(getBytes(photo(id, "stranger")));
  await assertFails(getMetadata(photo(id, "stranger")));
  await assertFails(getBytes(photo(id, "fake-dispatcher", { dispatcher: "true" })));
  await assertFails(getBytes(ref(env.unauthenticatedContext().storage(bucket), `jobs/${id}/photo.jpg`)));
  await assertFails(deleteObject(photo(id, "stranger")));
  await assertFails(deleteObject(photo(id, "dispatcher", { dispatcher: true })));
  await assertSucceeds(deleteObject(photo(id)));
  await assertSucceeds(uploadBytes(photo(id), png, metadata()));
  await setDoc(doc(firestore(), "triageJobs", id), data(id));
  await assertFails(deleteObject(photo(id)));
  const existing = "doc-before-upload";
  await setDoc(doc(firestore(), "triageJobs", existing), data(existing));
  await assertFails(uploadBytes(photo(existing), png, metadata()));
});

test("internal quota counters deny every client read and write, including anonymous and dispatcher", async () => {
  for (const usage of usageRefs()) {
    await usage.set({ count: 1 });
    for (const client of [env.unauthenticatedContext().firestore(), firestore(), firestore("anon", { firebase: { sign_in_provider: "anonymous" } }), firestore("dispatcher", { dispatcher: true })]) {
      await assertFails(getDoc(doc(client, usage.path)));
      await assertFails(setDoc(doc(client, `${usage.path}-new`), { count: 0 }));
      await assertFails(updateDoc(doc(client, usage.path), { count: 0 }));
      await assertFails(deleteDoc(doc(client, usage.path)));
    }
  }
});

test("atomic claims admit one worker, charge once, retry active duplicates and sanitize failures", async () => {
  const id = "atomic-claim";
  await setDoc(doc(firestore(), "triageJobs", id), data(id));
  const jobRef = db.doc(`triageJobs/${id}`);
  const claims = await Promise.allSettled(Array.from({ length: 8 }, () => triage.claimJob(jobRef, id)));
  const admitted = claims.filter((claim) => claim.status === "fulfilled");
  assert.equal(admitted.length, 1);
  assert.equal(admitted[0].value.attempt, 1);
  for (const claim of claims.filter((claim) => claim.status === "rejected")) {
    assert.ok(claim.reason instanceof triage.ActiveLeaseError);
  }
  assert.equal((await jobRef.get()).get("status"), "ANALYZING");
  for (const usage of usageRefs()) assert.equal((await usage.get()).get("count"), 1);
  await triage.finishJob(jobRef, 0);
  await triage.finishJob(jobRef, 2, result);
  assert.equal((await jobRef.get()).get("status"), "ANALYZING");
  await triage.finishJob(jobRef, 1);
  const failed = (await jobRef.get()).data();
  assert.equal(failed.status, "TRIAGE_FAILED");
  assert.equal(failed.error, triage.SAFE_ERROR);
  assert.ok(failed.failedAt instanceof AdminTimestamp);
  await triage.finishJob(jobRef, 1, result);
  assert.equal((await jobRef.get()).get("status"), "TRIAGE_FAILED");
  assert.equal(await triage.claimJob(jobRef, id), undefined);
  assert.equal(await triage.claimJob(db.doc("triageJobs/nonexistent"), "nonexistent"), undefined);
});

test("owner admission is capped at ten and concurrent rejections never load images or call AI", async (t) => {
  const { processJobTriage } = require("../lib/index");
  const imageMock = t.mock.method(triage, "loadJobImage", async () => "test");
  const modelMock = t.mock.method(triage, "analyzeJob", async () => result);
  assert.equal(triage.OWNER_DAILY_LIMIT, 10);
  assert.equal(triage.GLOBAL_DAILY_LIMIT, 100);
  for (let i = 0; i < 9; i++) {
    const id = `quota-owner-${i}`;
    await setDoc(doc(firestore(), "triageJobs", id), data(id));
    assert.equal((await triage.claimJob(db.doc(`triageJobs/${id}`), id)).attempt, 1);
  }
  const refs = await Promise.all([9, 10, 11].map(async (i) => {
    const id = `quota-owner-${i}`;
    await setDoc(doc(firestore(), "triageJobs", id), data(id));
    return db.doc(`triageJobs/${id}`);
  }));
  await Promise.all(refs.map(async (jobRef) => processJobTriage.run({ data: await jobRef.get(), params: { jobId: jobRef.id } })));
  const jobs = await Promise.all(refs.map(async (jobRef) => (await jobRef.get()).data()));
  assert.equal(jobs.filter((job) => job.status === "TRIAGED").length, 1);
  for (const job of jobs.filter((job) => job.status !== "TRIAGED")) {
    assert.equal(job.status, "TRIAGE_FAILED");
    assert.equal(job.error, triage.QUOTA_ERROR);
    assert.equal(job.analysisAttempts, undefined);
    assert.ok(job.failedAt instanceof AdminTimestamp);
  }
  for (const jobRef of refs) await processJobTriage.run({ data: await jobRef.get(), params: { jobId: jobRef.id } });
  for (const usage of usageRefs()) assert.equal((await usage.get()).get("count"), 10);
  assert.equal(imageMock.mock.callCount(), 1);
  assert.equal(modelMock.mock.callCount(), 1);
});

test("global quota serializes competing owners at 100 without charging rejected owners", async () => {
  const [globalRef] = usageRefs();
  await globalRef.set({ count: 99 });
  const claims = await Promise.all(["owner-a", "owner-b", "owner-c"].map(async (ownerId) => {
    const id = `global-${ownerId}`;
    await setDoc(doc(firestore(ownerId), "triageJobs", id), data(id, ownerId));
    const jobRef = db.doc(`triageJobs/${id}`);
    const claim = await triage.claimJob(jobRef, id);
    const ownerUsage = await usageRefs(undefined, ownerId)[1].get();
    assert.equal(ownerUsage.exists, Boolean(claim));
    if (claim) assert.equal(ownerUsage.get("count"), 1);
    else assert.equal((await jobRef.get()).get("error"), triage.QUOTA_ERROR);
    return claim;
  }));
  assert.equal(claims.filter(Boolean).length, 1);
  assert.equal((await globalRef.get()).get("count"), 100);
});

test("quota rolls over at UTC midnight but stale recovery never charges another day", async (t) => {
  let now = Date.parse("2026-09-22T23:59:59.999Z");
  t.mock.method(Date, "now", () => now);
  const [globalRef, ownerRef] = usageRefs("2026-09-22");
  await globalRef.set({ count: 99 });
  await ownerRef.set({ count: 9 });
  const id = "utc-first";
  const jobRef = db.doc(`triageJobs/${id}`);
  await jobRef.set({ ...data(id), createdAt: AdminTimestamp.fromMillis(now) });
  assert.equal((await triage.claimJob(jobRef, id)).attempt, 1);
  await jobRef.update({ analysisStartedAt: AdminTimestamp.fromMillis(now - triage.ANALYSIS_LEASE_MS - 1) });
  now++;
  assert.equal((await triage.claimJob(jobRef, id)).attempt, 2);
  for (const usage of usageRefs("2026-09-23")) assert.equal((await usage.get()).exists, false);
  const next = db.doc("triageJobs/utc-next");
  await next.set({ ...data(next.id), createdAt: AdminTimestamp.fromMillis(now) });
  assert.equal((await triage.claimJob(next, next.id)).attempt, 1);
  for (const usage of usageRefs("2026-09-23")) assert.equal((await usage.get()).get("count"), 1);
  assert.equal((await globalRef.get()).get("count"), 100);
  assert.equal((await ownerRef.get()).get("count"), 10);
});

test("corrupt counters fail closed rather than resetting the spending budget", async () => {
  const [globalRef, ownerRef] = usageRefs();
  for (const [index, count] of [-1, 0.5, "0", null].entries()) {
    await globalRef.set({ count });
    const id = `bad-quota-${index}`;
    const jobRef = db.doc(`triageJobs/${id}`);
    await jobRef.set({ ...data(id), createdAt: AdminTimestamp.now() });
    assert.equal(await triage.claimJob(jobRef, id), undefined);
    assert.equal((await jobRef.get()).get("error"), triage.QUOTA_ERROR);
  }
  await globalRef.set({ count: 0 });
  await ownerRef.set({ count: "0" });
  const jobRef = db.doc("triageJobs/bad-owner-quota");
  await jobRef.set({ ...data(jobRef.id), createdAt: AdminTimestamp.now() });
  assert.equal(await triage.claimJob(jobRef, jobRef.id), undefined);
  assert.equal((await globalRef.get()).get("count"), 0);
  assert.equal((await jobRef.get()).get("error"), triage.QUOTA_ERROR);
});

test("lease expires strictly after four minutes, fences old writers, and stops after three claims", async (t) => {
  const id = "recover-crash";
  const jobRef = db.doc(`triageJobs/${id}`);
  await setDoc(doc(firestore(), "triageJobs", id), data(id));
  const first = await triage.claimJob(jobRef, id);
  assert.equal(first.attempt, 1);
  assert.equal(triage.ANALYSIS_LEASE_MS, 240_000);
  assert.equal(triage.MAX_ANALYSIS_ATTEMPTS, 3);
  let now = Date.now();
  await jobRef.update({ analysisStartedAt: AdminTimestamp.fromMillis(now - triage.ANALYSIS_LEASE_MS) });
  t.mock.method(Date, "now", () => now);
  await assert.rejects(triage.claimJob(jobRef, id), triage.ActiveLeaseError);
  now++;
  const claims = await Promise.allSettled([triage.claimJob(jobRef, id), triage.claimJob(jobRef, id)]);
  const winner = claims.find((claim) => claim.status === "fulfilled");
  assert.equal(winner.value.attempt, 2);
  assert.deepEqual(winner.value.job, first.job);
  assert.ok(claims.find((claim) => claim.status === "rejected").reason instanceof triage.ActiveLeaseError);
  const { processJobTriage } = require("../lib/index");
  t.mock.method(require("firebase-functions/logger"), "error", () => {});
  const claimMock = t.mock.method(triage, "claimJob", async () => first);
  t.mock.method(triage, "loadJobImage", async () => "test");
  const modelMock = t.mock.method(triage, "analyzeJob", async () => result);
  const oldEvent = { data: await jobRef.get(), params: { jobId: id } };
  await processJobTriage.run(oldEvent);
  modelMock.mock.mockImplementation(async () => { throw new Error("old worker failure"); });
  await processJobTriage.run(oldEvent);
  claimMock.mock.restore();
  assert.equal((await jobRef.get()).get("status"), "ANALYZING");
  assert.equal((await jobRef.get()).get("analysisAttempts"), 2);
  now = (await jobRef.get()).get("analysisStartedAt").toMillis() + triage.ANALYSIS_LEASE_MS + 1;
  assert.equal((await triage.claimJob(jobRef, id)).attempt, 3);
  now = (await jobRef.get()).get("analysisStartedAt").toMillis();
  await assert.rejects(triage.claimJob(jobRef, id), triage.ActiveLeaseError);
  now += triage.ANALYSIS_LEASE_MS + 1;
  assert.equal(await triage.claimJob(jobRef, id), undefined);
  const failed = (await jobRef.get()).data();
  assert.equal(failed.status, "TRIAGE_FAILED");
  assert.equal(failed.analysisAttempts, 3);
  assert.equal(failed.error, triage.SAFE_ERROR);
  await triage.finishJob(jobRef, 3, result);
  assert.equal((await jobRef.get()).get("status"), "TRIAGE_FAILED");
  for (const usage of usageRefs()) assert.equal((await usage.get()).get("count"), 1);
});

test("legacy ANALYZING jobs without an attempt counter recover as attempt two", async () => {
  const id = "legacy-crash";
  const jobRef = db.doc(`triageJobs/${id}`);
  const job = { ...data(id), createdAt: AdminTimestamp.now() };
  await jobRef.set({ ...job, status: "ANALYZING", analysisStartedAt: AdminTimestamp.now() });
  await assert.rejects(triage.claimJob(jobRef, id), triage.ActiveLeaseError);
  await jobRef.update({ analysisStartedAt: AdminTimestamp.fromMillis(Date.now() - triage.ANALYSIS_LEASE_MS - 1) });
  const claim = await triage.claimJob(jobRef, id);
  assert.equal(claim.attempt, 2);
  assert.deepEqual(claim.job, job);
  for (const usage of usageRefs()) assert.equal((await usage.get()).exists, false);
  await triage.finishJob(jobRef, claim.attempt, result);
  assert.equal((await jobRef.get()).get("status"), "TRIAGED");
});

test("reclaims validate exact stored input and only strip the server lease fields", async (t) => {
  const { processJobTriage } = require("../lib/index");
  const modelMock = t.mock.method(triage, "analyzeJob", async () => result);
  const patches = [
    { description: "x".repeat(4001) }, { ownerId: "" }, { id: "different" },
    { customer: { ...data("unused").customer, extra: true } },
    { media: { storagePath: "jobs/other/photo.jpg" } }, { unexpected: true },
    { aiAnalysis: result }, { analysisAttempts: -1 }, { analysisAttempts: 1.5 },
    { analysisStartedAt: "not a timestamp" },
  ];
  for (const [index, patch] of patches.entries()) {
    const id = `bad-reclaim-${index}`;
    const jobRef = db.doc(`triageJobs/${id}`);
    await jobRef.set({
      ...data(id), createdAt: AdminTimestamp.now(), status: "ANALYZING", analysisAttempts: 1,
      analysisStartedAt: AdminTimestamp.fromMillis(Date.now() - triage.ANALYSIS_LEASE_MS - 1), ...patch,
    });
    await processJobTriage.run({ data: await jobRef.get(), params: { jobId: id } });
    assert.equal((await jobRef.get()).get("status"), "TRIAGE_FAILED");
    assert.equal((await jobRef.get()).get("error"), triage.SAFE_ERROR);
  }
  assert.equal(modelMock.mock.callCount(), 0);
  for (const usage of usageRefs()) assert.equal((await usage.get()).exists, false);
});

test("storage loader validates actual owner and image signature before model access", async () => {
  const id = "load-image";
  await uploadBytes(photo(id), png, metadata());
  const job = { ...data(id), createdAt: AdminTimestamp.now() };
  assert.match(await triage.loadJobImage(job), /^data:image\/png;base64,/);
  await assert.rejects(triage.loadJobImage({ ...job, ownerId: "stranger" }));
  const fakeId = "fake-image";
  await uploadBytes(photo(fakeId), Buffer.from("fake png"), metadata());
  await assert.rejects(triage.loadJobImage({ ...job, id: fakeId, media: { storagePath: `jobs/${fakeId}/photo.jpg` } }));
});

test("trigger retries active duplicates without overlapping inference and recovers a crashed claim", async (t) => {
  const { processJobTriage } = require("../lib/index");
  assert.equal(processJobTriage.__endpoint.eventTrigger.retry, true);
  assert.equal(processJobTriage.__endpoint.timeoutSeconds, 180);
  const logs = t.mock.method(require("firebase-functions/logger"), "error", () => {});
  t.mock.method(triage, "loadJobImage", async () => "test");
  const entered = Promise.withResolvers();
  const release = Promise.withResolvers();
  const modelMock = t.mock.method(triage, "analyzeJob", async () => {
    entered.resolve();
    await release.promise;
    return result;
  });
  const id = "trigger-active";
  await setDoc(doc(firestore(), "triageJobs", id), data(id));
  const jobRef = db.doc(`triageJobs/${id}`);
  const event = { data: await jobRef.get(), params: { jobId: id } };
  const worker = processJobTriage.run(event);
  await entered.promise;
  try {
    await assert.rejects(processJobTriage.run(event), triage.ActiveLeaseError);
    assert.equal((await jobRef.get()).get("status"), "ANALYZING");
    assert.equal(modelMock.mock.callCount(), 1);
    assert.equal(logs.mock.callCount(), 0);
  } finally {
    release.resolve();
    await worker;
  }
  await processJobTriage.run(event);
  await triage.finishJob(jobRef, 1);
  assert.equal((await jobRef.get()).get("status"), "TRIAGED");
  assert.equal(modelMock.mock.callCount(), 1);
  modelMock.mock.mockImplementation(async () => result);
  const crashed = db.doc("triageJobs/trigger-crashed");
  await crashed.set({ ...data(crashed.id), createdAt: AdminTimestamp.now() });
  const crashEvent = { data: await crashed.get(), params: { jobId: crashed.id } };
  await triage.claimJob(crashed, crashed.id);
  await assert.rejects(processJobTriage.run(crashEvent), triage.ActiveLeaseError);
  await crashed.update({ analysisStartedAt: AdminTimestamp.fromMillis(Date.now() - triage.ANALYSIS_LEASE_MS - 1) });
  await processJobTriage.run(crashEvent);
  assert.equal((await crashed.get()).get("status"), "TRIAGED");
  assert.equal((await crashed.get()).get("analysisAttempts"), 2);
  assert.equal(modelMock.mock.callCount(), 2);
  for (const usage of usageRefs()) assert.equal((await usage.get()).get("count"), 2);
});

test("claim infrastructure errors retry without failing an unowned lease or leaking details", async (t) => {
  const { processJobTriage } = require("../lib/index");
  const logs = t.mock.method(require("firebase-functions/logger"), "error", () => {});
  const modelMock = t.mock.method(triage, "analyzeJob", async () => result);
  const finishMock = t.mock.method(triage, "finishJob", async () => {});
  const jobRef = db.doc("triageJobs/claim-infrastructure");
  await jobRef.set({ ...data(jobRef.id), createdAt: AdminTimestamp.now() });
  t.mock.method(triage, "claimJob", async () => { throw new Error("private database details"); });
  await assert.rejects(processJobTriage.run({ data: await jobRef.get(), params: { jobId: jobRef.id } }), { message: "TRIAGE_CLAIM_FAILED" });
  assert.equal((await jobRef.get()).get("status"), "RECEIVED");
  assert.equal(modelMock.mock.callCount(), 0);
  assert.equal(finishMock.mock.callCount(), 0);
  assert.deepEqual(logs.mock.calls.map((call) => call.arguments), [["TRIAGE_PROCESSING_FAILED"]]);
});

test("trigger persists success once and sanitized failure without logging customer evidence", async (t) => {
  const logger = require("firebase-functions/logger");
  const logs = t.mock.method(logger, "error", () => {});
  const { processJobTriage } = require("../lib/index");
  const imageMock = t.mock.method(triage, "loadJobImage", async () => "data:image/png;base64,test");
  const modelMock = t.mock.method(triage, "analyzeJob", async () => result);
  const id = "trigger-success";
  await setDoc(doc(firestore(), "triageJobs", id), data(id));
  const jobRef = db.doc(`triageJobs/${id}`);
  const event = { data: await jobRef.get(), params: { jobId: id } };
  await processJobTriage.run(event);
  await processJobTriage.run(event);
  const success = (await jobRef.get()).data();
  assert.equal(success.status, "TRIAGED");
  assert.deepEqual(success.aiAnalysis, result);
  assert.ok(success.triagedAt instanceof AdminTimestamp);
  assert.equal(modelMock.mock.callCount(), 1);
  assert.equal(imageMock.mock.callCount(), 1);
  modelMock.mock.mockImplementation(async () => { throw new Error("secret prompt photo owner data"); });
  const failedId = "trigger-failure";
  await setDoc(doc(firestore(), "triageJobs", failedId), data(failedId));
  const failedRef = db.doc(`triageJobs/${failedId}`);
  await processJobTriage.run({ data: await failedRef.get(), params: { jobId: failedId } });
  assert.equal((await failedRef.get()).get("error"), triage.SAFE_ERROR);
  assert.equal((await failedRef.get()).get("status"), "TRIAGE_FAILED");
  assert.deepEqual(logs.mock.calls.map((call) => call.arguments), [["TRIAGE_PROCESSING_FAILED"]]);
  const malformed = db.doc("triageJobs/malformed");
  await malformed.set({ status: "RECEIVED", description: "private evidence" });
  await processJobTriage.run({ data: await malformed.get(), params: { jobId: "malformed" } });
  assert.equal((await malformed.get()).get("error"), triage.SAFE_ERROR);
  assert.equal((await malformed.get()).get("status"), "TRIAGE_FAILED");
  const persistId = "failure-persistence";
  await setDoc(doc(firestore(), "triageJobs", persistId), data(persistId));
  t.mock.method(triage, "finishJob", async () => { throw new Error("private database details"); });
  await assert.rejects(processJobTriage.run({ data: await db.doc(`triageJobs/${persistId}`).get(), params: { jobId: persistId } }), { message: "TRIAGE_FAILURE_PERSISTENCE_FAILED" });
  assert.equal(JSON.stringify(logs.mock.calls.map((call) => call.arguments)).includes("private"), false);
  await processJobTriage.run({ data: undefined, params: { jobId: "none" } });
});
