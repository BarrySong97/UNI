import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { headers } from "next/headers";
import { isRTL } from "@heroui/react";
import { ClientProviders } from "./provider";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

const title = "Immersed - Read smarter. Learn faster.";
const description =
  "Immersed turns books and articles into an immersive language-learning loop with instant word lookup, saved vocabulary, and focused reading.";

export const metadata: Metadata = {
  applicationName: "Immersed",
  title: {
    default: title,
    template: "%s | Immersed",
  },
  description,
  keywords: [
    "Immersed",
    "language learning",
    "reading app",
    "vocabulary builder",
    "ebook reader",
    "learn English",
    "immersive reading",
  ],
  alternates: {
    canonical: "/",
  },
  openGraph: {
    type: "website",
    url: "/",
    siteName: "Immersed",
    title,
    description,
    images: [
      {
        url: "/og-image.png",
        width: 1200,
        height: 630,
        alt: "Immersed app preview",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title,
    description,
    images: ["/og-image.png"],
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-image-preview": "large",
      "max-snippet": -1,
      "max-video-preview": -1,
    },
  },
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const acceptLanguage = (await headers()).get("accept-language");
  const lang = acceptLanguage?.split(/[,;]/)[0] || "en-US";

  return (
    <html
      lang={lang}
      dir={isRTL(lang) ? "rtl" : "ltr"}
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col font-sans">
        <ClientProviders lang={lang}>{children}</ClientProviders>
      </body>
    </html>
  );
}
