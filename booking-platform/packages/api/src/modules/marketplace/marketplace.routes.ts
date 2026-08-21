import { Router } from "express";
import { asyncHandler } from "../../middleware/errorHandler";
import * as marketplaceService from "./marketplace.service";

export const marketplaceRouter = Router();

marketplaceRouter.get(
  "/businesses",
  asyncHandler(async (req, res) => {
    const results = await marketplaceService.search(req.query as Record<string, unknown>);
    res.json({ results });
  })
);
