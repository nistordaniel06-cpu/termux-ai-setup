import { Router } from "express";
import { asyncHandler } from "../../middleware/errorHandler";
import { requireAuth } from "../../middleware/auth";
import { updateServiceSchema } from "./service.schema";
import * as serviceService from "./service.service";

export const serviceRouter = Router();

serviceRouter.patch(
  "/:id",
  requireAuth,
  asyncHandler(async (req, res) => {
    const input = updateServiceSchema.parse(req.body);
    const service = await serviceService.updateService(req.params.id, req.auth!.userId, input);
    res.json(service);
  })
);

serviceRouter.delete(
  "/:id",
  requireAuth,
  asyncHandler(async (req, res) => {
    await serviceService.deleteService(req.params.id, req.auth!.userId);
    res.status(204).send();
  })
);
