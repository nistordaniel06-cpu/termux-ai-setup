-- DropIndex
DROP INDEX "Booking_professionalId_startTime_key";

-- CreateIndex
CREATE INDEX "Booking_professionalId_startTime_idx" ON "Booking"("professionalId", "startTime");
