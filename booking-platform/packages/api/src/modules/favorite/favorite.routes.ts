import { Router } from "express";
import { asyncHandler } from "../../middleware/errorHandler";
import { requireAuth } from "../../middleware/auth";
import * as favoriteService from "./favorite.service";

export const favoriteRouter = Router();

favoriteRouter.get(
  "/me",
  requireAuth,
  asyncHandler(async (req, res) => {
    const favorites = await favoriteService.listMyFavorites(req.auth!.userId);
    res.json(favorites);
  })
);
