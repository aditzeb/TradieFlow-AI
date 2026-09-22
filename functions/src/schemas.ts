import { Timestamp } from "firebase-admin/firestore";
import { z } from "zod";

export const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
export const JobIdSchema = z.string().regex(/^[A-Za-z0-9_-]{1,128}$/);
export const AustralianStateSchema = z.enum(["NSW", "VIC", "QLD", "SA", "WA", "TAS", "NT", "ACT"]);

const postcodeRanges: Record<z.infer<typeof AustralianStateSchema>, readonly (readonly [number, number])[]> = {
  NSW: [[1000, 2599], [2619, 2899], [2921, 2999]],
  ACT: [[200, 299], [2600, 2618], [2900, 2920]],
  VIC: [[3000, 3999], [8000, 8999]],
  QLD: [[4000, 4999], [9000, 9999]],
  SA: [[5000, 5999]],
  WA: [[6000, 6797], [6800, 6999]],
  TAS: [[7000, 7999]],
  NT: [[800, 999]],
};

export const CustomerSchema = z.strictObject({
  suburb: z.string().min(1).max(80).refine((value) => value === value.trim() && !/[\p{Cc}]/u.test(value)),
  state: AustralianStateSchema,
  postcode: z.string().regex(/^\d{4}$/),
}).refine(({ state, postcode }) => postcodeRanges[state].some(([min, max]) => Number(postcode) >= min && Number(postcode) <= max));

export const JobInputSchema = z.strictObject({
  id: JobIdSchema,
  ownerId: z.string().min(1).max(128),
  createdAt: z.instanceof(Timestamp),
  status: z.literal("RECEIVED"),
  customer: CustomerSchema,
  description: z.string().max(4000),
  media: z.strictObject({ storagePath: z.string().max(143) }),
}).refine(({ id, media }) => media.storagePath === `jobs/${id}/photo.jpg`);

const text = (max: number) => z.string().min(1).max(max).regex(/\S/);
const money = z.number().min(0).max(100_000);

export const TriageOutputSchema = z.strictObject({
  urgency: z.enum(["P1_EMERGENCY", "P2_SAME_DAY", "P3_ROUTINE"]),
  urgencyReasoning: text(1200).describe("Advisory reasoning only; no compliance certification or invented AS/NZS clauses."),
  hazardIdentified: z.boolean(),
  immediateSafetyAction: text(1200).describe("Non-invasive safety guidance only. Never suggest DIY electrical or gas repair."),
  appliance: z.strictObject({
    brand: text(120).describe("Visible brand or Unknown; never infer from appearance alone."),
    modelNumber: text(120).describe("Exact legible plate text, Unreadable for an illegible plate, or Unknown if absent."),
    type: text(120),
    estimatedAgeBracket: z.enum(["< 5 years", "5-10 years", "> 10 years", "Unknown"]),
  }),
  faultDiagnostic: text(2000).describe("Possible causes, not a confirmed diagnosis; licensed on-site inspection required."),
  recommendedParts: z.array(text(160)).max(20),
  estimatedLaborHours: z.number().min(0.5).max(12),
  quoteAud: z.strictObject({
    calloutFee: money,
    laborCost: money,
    partsCost: money,
    gst: z.number().min(0).max(30_000),
    totalEstimate: z.number().min(0).max(330_000),
  }).describe("Non-binding AUD estimate. Base line items exclude GST; server recomputes 10% GST and total."),
  dynamicClarification: text(1000).describe("One useful clarification; ask for a clearer label photo when OCR is uncertain."),
});

export const TriageOutputJsonSchema = z.toJSONSchema(TriageOutputSchema);
export type TriageOutput = z.infer<typeof TriageOutputSchema>;
export type JobInput = z.infer<typeof JobInputSchema>;

export function normalizeAnalysis(input: unknown): TriageOutput {
  const analysis = TriageOutputSchema.parse(input);
  const cents = [analysis.quoteAud.calloutFee, analysis.quoteAud.laborCost, analysis.quoteAud.partsCost]
    .map((amount) => Math.round((amount + Number.EPSILON * Math.max(1, amount)) * 100));
  const subtotal = cents.reduce((sum, amount) => sum + amount, 0);
  const gst = Math.round(subtotal / 10);
  analysis.quoteAud = {
    calloutFee: cents[0]! / 100,
    laborCost: cents[1]! / 100,
    partsCost: cents[2]! / 100,
    gst: gst / 100,
    totalEstimate: (subtotal + gst) / 100,
  };
  analysis.immediateSafetyAction = analysis.hazardIdentified || analysis.urgency === "P1_EMERGENCY"
    ? "Keep clear and stop using the affected equipment. Do not touch, open, test or repair it. Contact a licensed tradesperson urgently; call 000 if there is immediate danger. Advisory only, not a safety or compliance certification."
    : "A photo cannot establish safety or compliance. Do not open or repair the equipment yourself. Arrange assessment by a licensed tradesperson. Advisory only, not a confirmed diagnosis or binding quote.";
  return TriageOutputSchema.parse(analysis);
}
