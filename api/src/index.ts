import "dotenv/config";
import express from "express";
import cors from "cors";
import { clerkMiddleware } from "@clerk/express";
import userRoutes from "./routes/users";
import groupRoutes from "./routes/groups";
import sessionRoutes from "./routes/sessions";
import { startCronJobs } from "./lib/cron";

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(clerkMiddleware());

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.use("/users", userRoutes);
app.use("/groups", groupRoutes);
app.use("/sessions", sessionRoutes);

app.listen(PORT, () => {
  console.log(`GroupSend API running on port ${PORT}`);
  startCronJobs();
});
