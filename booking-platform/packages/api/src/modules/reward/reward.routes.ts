import { Router } from "express";
import { asyncHandler } from "../../middleware/errorHandler";
import { requireAuth } from "../../middleware/auth";
import * as rewardService from "./reward.service";

export const rewardRouter = Router();

rewardRouter.get(
  "/me",
  requireAuth,
  asyncHandler(async (req, res) => {
    const rewards = await rewardService.listMyRewards(req.auth!.userId);
    res.json(rewards);
  })
);
