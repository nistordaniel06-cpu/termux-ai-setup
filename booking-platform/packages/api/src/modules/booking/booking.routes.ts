import { Router } from "express";
import { asyncHandler } from "../../middleware/errorHandler";
import { requireAuth } from "../../middleware/auth";
import { createBookingSchema, rescheduleBookingSchema } from "./booking.schema";
import * as bookingService from "./booking.service";

export const bookingRouter = Router();

bookingRouter.post(
  "/",
  requireAuth,
  asyncHandler(async (req, res) => {
    const input = createBookingSchema.parse(req.body);
    const booking = await bookingService.createBooking(req.auth!.userId, input);
    res.status(201).json(booking);
  })
);

bookingRouter.get(
  "/me",
  requireAuth,
  asyncHandler(async (req, res) => {
    const bookings = await bookingService.listMyBookings(req.auth!.userId);
    res.json(bookings);
  })
);

bookingRouter.get(
  "/business/:id",
  requireAuth,
  asyncHandler(async (req, res) => {
    const bookings = await bookingService.listBusinessBookings(req.params.id, req.auth!.userId);
    res.json(bookings);
  })
);

bookingRouter.patch(
  "/:id/cancel",
  requireAuth,
  asyncHandler(async (req, res) => {
    const booking = await bookingService.cancelBooking(req.params.id, req.auth!.userId);
    res.json(booking);
  })
);

bookingRouter.patch(
  "/:id/reschedule",
  requireAuth,
  asyncHandler(async (req, res) => {
    const { startTime } = rescheduleBookingSchema.parse(req.body);
    const booking = await bookingService.rescheduleBooking(req.params.id, req.auth!.userId, startTime);
    res.json(booking);
  })
);
