import { Router } from "express";
import { asyncHandler } from "../../middleware/errorHandler";
import { requireAuth } from "../../middleware/auth";
import * as dashboardService from "./dashboard.service";

export const dashboardRouter = Router();

dashboardRouter.get(
  "/:businessId",
  requireAuth,
  asyncHandler(async (req, res) => {
    const dashboard = await dashboardService.getDashboard(req.params.businessId, req.auth!.userId);
    res.json(dashboard);
  })
);
