import { Router } from "express";
import { asyncHandler } from "../../middleware/errorHandler";
import { requireAuth } from "../../middleware/auth";
import {
  updateProfessionalSchema,
  setScheduleSchema,
  addAvailabilityOverrideSchema,
  getOpenSlotsQuerySchema,
} from "./professional.schema";
import * as professionalService from "./professional.service";

export const professionalRouter = Router();

professionalRouter.patch(
  "/:id",
  requireAuth,
  asyncHandler(async (req, res) => {
    const input = updateProfessionalSchema.parse(req.body);
    const professional = await professionalService.updateProfessional(req.params.id, req.auth!.userId, input);
    res.json(professional);
  })
);

professionalRouter.post(
  "/:id/schedule",
  requireAuth,
  asyncHandler(async (req, res) => {
    const input = setScheduleSchema.parse(req.body);
    const schedule = await professionalService.setSchedule(req.params.id, req.auth!.userId, input);
    res.status(201).json(schedule);
  })
);

professionalRouter.get(
  "/:id/schedule",
  asyncHandler(async (req, res) => {
    const schedule = await professionalService.getSchedule(req.params.id);
    res.json(schedule);
  })
);

professionalRouter.post(
  "/:id/availability",
  requireAuth,
  asyncHandler(async (req, res) => {
    const input = addAvailabilityOverrideSchema.parse(req.body);
    const availability = await professionalService.addAvailabilityOverride(req.params.id, req.auth!.userId, input);
    res.status(201).json(availability);
  })
);

professionalRouter.get(
  "/:id/availability",
  asyncHandler(async (req, res) => {
    const { date, serviceId } = getOpenSlotsQuerySchema.parse(req.query);
    const slots = await professionalService.computeOpenSlots(req.params.id, date, serviceId);
    res.json({ slots });
  })
);
