import { Router } from "express";
import { asyncHandler } from "../../middleware/errorHandler";
import { requireAuth } from "../../middleware/auth";
import { createBusinessSchema, updateBusinessSchema, addProfessionalSchema, addServiceSchema } from "./business.schema";
import * as businessService from "./business.service";

export const businessRouter = Router();

businessRouter.post(
  "/",
  requireAuth,
  asyncHandler(async (req, res) => {
    const input = createBusinessSchema.parse(req.body);
    const business = await businessService.createBusiness(req.auth!.userId, req.auth!.role, input);
    res.status(201).json(business);
  })
);

businessRouter.get(
  "/me",
  requireAuth,
  asyncHandler(async (req, res) => {
    const business = await businessService.getMyBusiness(req.auth!.userId);
    res.json(business);
  })
);

businessRouter.get(
  "/:id",
  asyncHandler(async (req, res) => {
    const business = await businessService.getBusinessById(req.params.id);
    res.json(business);
  })
);

businessRouter.patch(
  "/:id",
  requireAuth,
  asyncHandler(async (req, res) => {
    const input = updateBusinessSchema.parse(req.body);
    const business = await businessService.updateBusiness(req.params.id, req.auth!.userId, input);
    res.json(business);
  })
);

businessRouter.post(
  "/:id/professionals",
  requireAuth,
  asyncHandler(async (req, res) => {
    const input = addProfessionalSchema.parse(req.body);
    const professional = await businessService.addProfessional(req.params.id, req.auth!.userId, input);
    res.status(201).json(professional);
  })
);

businessRouter.get(
  "/:id/professionals",
  asyncHandler(async (req, res) => {
    const professionals = await businessService.listProfessionals(req.params.id);
    res.json(professionals);
  })
);

businessRouter.post(
  "/:id/services",
  requireAuth,
  asyncHandler(async (req, res) => {
    const input = addServiceSchema.parse(req.body);
    const service = await businessService.addService(req.params.id, req.auth!.userId, input);
    res.status(201).json(service);
  })
);

businessRouter.get(
  "/:id/services",
  asyncHandler(async (req, res) => {
    const services = await businessService.listServices(req.params.id);
    res.json(services);
  })
);
