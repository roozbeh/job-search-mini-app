import { createBrowserRouter } from "react-router";
import { Layout } from "./components/Layout";
import { ResumeUpload } from "./components/ResumeUpload";
import { ResumeReview } from "./components/ResumeReview";
import { Preferences } from "./components/Preferences";
import { JobBrowser } from "./components/JobBrowser";
import { SavedJobs } from "./components/SavedJobs";
import { JobDetail } from "./components/JobDetail";
import { Support } from "./components/Support";

export const router = createBrowserRouter([
  { path: "/support", Component: Support },
  {
    path: "/",
    Component: Layout,
    children: [
      { index: true, Component: ResumeUpload },
      { path: "resume-review", Component: ResumeReview },
      { path: "preferences", Component: Preferences },
      { path: "jobs", Component: JobBrowser },
      { path: "saved-jobs", Component: SavedJobs },
      { path: "job/:id", Component: JobDetail },
    ],
  },
]);
