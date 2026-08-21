-- AlterTable
ALTER TABLE "Business" ADD COLUMN     "loyaltyVisitsRequired" INTEGER,
ADD COLUMN     "maxDiscountPercent" INTEGER,
ADD COLUMN     "minDiscountPercent" INTEGER;

-- AlterTable
ALTER TABLE "Reward" ADD COLUMN     "businessId" TEXT;

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "notificationsEnabled" BOOLEAN NOT NULL DEFAULT true;

-- CreateIndex
CREATE INDEX "Offer_businessId_endsAt_idx" ON "Offer"("businessId", "endsAt");

-- AddForeignKey
ALTER TABLE "Reward" ADD CONSTRAINT "Reward_businessId_fkey" FOREIGN KEY ("businessId") REFERENCES "Business"("id") ON DELETE SET NULL ON UPDATE CASCADE;
