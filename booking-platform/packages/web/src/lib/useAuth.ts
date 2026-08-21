"use client";

import { useEffect, useState } from "react";
import { getStoredAuth, StoredAuth } from "./api";

export function useAuth() {
  const [auth, setAuth] = useState<StoredAuth | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    setAuth(getStoredAuth());
    setReady(true);
  }, []);

  return { auth, ready, setAuth };
}
