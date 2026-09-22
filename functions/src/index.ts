import { initializeApp } from "firebase-admin/app";
import { defineSecret, defineString } from "firebase-functions/params";
import { error as logError } from "firebase-functions/logger";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { ActiveLeaseError, analyzeJob, claimJob, finishJob, loadJobImage } from "./triage";

initializeApp();

const openRouterApiKey = defineSecret("OPENROUTER_API_KEY");
const openRouterModel = defineString("OPENROUTER_MODEL", { default: "google/gemini-2.0-flash-001" });

export const processJobTriage = onDocumentCreated({
  document: "triageJobs/{jobId}",
  region: "australia-southeast1",
  secrets: [openRouterApiKey],
  timeoutSeconds: 180,
  memory: "512MiB",
  maxInstances: 10,
  concurrency: 10,
  retry: true,
}, async (event) => {
  if (!event.data) return;
  const ref = event.data.ref;
  let attempt: number | undefined;
  try {
    const claim = await claimJob(ref, event.params.jobId);
    if (!claim) return;
    attempt = claim.attempt;
    const image = await loadJobImage(claim.job);
    const analysis = await analyzeJob(claim.job, image, openRouterApiKey.value(), openRouterModel.value());
    await finishJob(ref, attempt, analysis);
  } catch (error) {
    if (error instanceof ActiveLeaseError) throw error;
    logError("TRIAGE_PROCESSING_FAILED");
    if (attempt === undefined) {
      const retryError = new Error("TRIAGE_CLAIM_FAILED");
      throw retryError;
    }
    try {
      await finishJob(ref, attempt);
    } catch {
      logError("TRIAGE_FAILURE_PERSISTENCE_FAILED");
      throw new Error("TRIAGE_FAILURE_PERSISTENCE_FAILED");
    }
  }
});
