import express from "express";
import cors from "cors";
import { authRouter } from "./modules/auth/auth.routes";
import { businessRouter } from "./modules/business/business.routes";
import { professionalRouter } from "./modules/professional/professional.routes";
import { serviceRouter } from "./modules/service/service.routes";
import { bookingRouter } from "./modules/booking/booking.routes";
import { dashboardRouter } from "./modules/analytics/dashboard.routes";
import { favoriteRouter } from "./modules/favorite/favorite.routes";
import { marketplaceRouter } from "./modules/marketplace/marketplace.routes";
import { errorHandler } from "./middleware/errorHandler";

export function createApp() {
  const app = express();
  app.use(cors());
  app.use(express.json());

  app.get("/health", (_req, res) => res.json({ status: "ok" }));

  const api = express.Router();
  api.use("/auth", authRouter);
  api.use("/businesses", businessRouter);
  api.use("/professionals", professionalRouter);
  api.use("/services", serviceRouter);
  api.use("/bookings", bookingRouter);
  api.use("/dashboard", dashboardRouter);
  api.use("/favorites", favoriteRouter);
  api.use("/marketplace", marketplaceRouter);
  app.use("/api/v1", api);

  app.use(errorHandler);

  return app;
}
