"use client";

import { useState, type FormEvent } from "react";
import { Button, Input } from "@heroui/react";

type Status = "idle" | "submitting" | "success" | "error";

export function WaitlistForm() {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<Status>("idle");
  const [message, setMessage] = useState<string | null>(null);

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!email || status === "submitting") return;

    setStatus("submitting");
    setMessage(null);

    try {
      const response = await fetch("/api/waitlist", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, source: "homepage" }),
      });
      const data = (await response.json().catch(() => null)) as {
        message?: string;
      } | null;

      if (!response.ok) {
        throw new Error(data?.message || "Request failed");
      }

      setStatus("success");
      setMessage(data?.message || "You're on the list. We'll be in touch soon.");
      setEmail("");
    } catch (error) {
      setStatus("error");
      setMessage(
        error instanceof Error
          ? error.message
          : "Something went wrong. Please try again.",
      );
    }
  }

  const isSubmitting = status === "submitting";

  return (
    <div className="w-full">
      <form
        onSubmit={onSubmit}
        className="flex w-full flex-col gap-3 sm:flex-row sm:items-center"
      >
        <Input
          type="email"
          name="email"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          placeholder="you@domain.com"
          aria-label="Email address"
          required
          className="h-11 flex-1 rounded-full border border-zinc-200 bg-white px-4 text-sm text-zinc-900 outline-none transition placeholder:text-zinc-400 focus:border-zinc-900 dark:border-zinc-800 dark:bg-zinc-950 dark:text-zinc-50 dark:focus:border-zinc-100"
        />
        <Button
          type="submit"
          variant="primary"
          size="md"
          isDisabled={isSubmitting}
          className="h-11 rounded-full px-6 text-sm font-medium"
        >
          {isSubmitting ? "Joining…" : "Join waitlist"}
        </Button>
      </form>

      {message ? (
        <p
          role="status"
          className={`mt-3 text-sm ${
            status === "success"
              ? "text-emerald-600 dark:text-emerald-400"
              : "text-red-600 dark:text-red-400"
          }`}
        >
          {message}
        </p>
      ) : null}
    </div>
  );
}
