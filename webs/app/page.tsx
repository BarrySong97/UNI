import Image from "next/image";
import { WaitlistForm } from "./_components/waitlist-form";

export default function Home() {
  return (
    <div className="flex flex-1 flex-col bg-zinc-50 dark:bg-black">
      <header className="mx-auto flex w-full max-w-6xl items-center justify-between px-6 py-6">
        <span className="text-lg font-semibold tracking-tight text-zinc-900 dark:text-zinc-50">
          Immersed
        </span>
        <span className="rounded-full border border-zinc-200 px-3 py-1 text-xs font-medium text-zinc-600 dark:border-zinc-800 dark:text-zinc-400">
          Private beta
        </span>
      </header>

      <main className="mx-auto flex w-full max-w-6xl flex-1 flex-col items-center px-6 pb-16">
        <section className="relative w-full overflow-hidden rounded-3xl shadow-xl">
          <Image
            src="/hero-bg.png"
            alt=""
            width={2400}
            height={1350}
            priority
            className="h-[420px] w-full object-cover sm:h-[520px] md:h-[600px]"
          />

          <div className="absolute inset-x-0 bottom-0 flex items-end justify-center px-4 pb-0 sm:px-8">
            <Image
              src="/hero-mock-mobile.png"
              alt=""
              width={960}
              height={720}
              priority
              className="block w-[260%] max-w-none translate-y-[30%] object-contain drop-shadow-2xl md:hidden"
            />
            <Image
              src="/hero-mocks.png"
              alt=""
              width={1600}
              height={1000}
              priority
              className="hidden w-full max-w-3xl translate-y-8 object-contain drop-shadow-2xl md:block md:max-w-4xl"
            />
          </div>
        </section>

        <section className="mt-20 grid w-full gap-10 md:grid-cols-2 md:items-center md:gap-16">
          <div>
            <h1 className="text-balance text-3xl font-semibold leading-tight tracking-tight text-zinc-900 sm:text-4xl dark:text-zinc-50">
              Read smarter. Learn the language as you go.
            </h1>
            <p className="mt-4 max-w-md text-base leading-7 text-zinc-600 dark:text-zinc-400">
              Immersed turns every book and article into an immersive learning
              loop — tap any word for instant meaning, save it to your deck,
              and keep reading without ever losing your place.
            </p>
          </div>

          <div className="md:justify-self-end md:max-w-md md:w-full">
            <p className="mb-3 text-sm font-medium text-zinc-900 dark:text-zinc-100">
              Join the waitlist
            </p>
            <WaitlistForm />
            <p className="mt-3 text-xs text-zinc-500 dark:text-zinc-500">
              No spam. We&apos;ll only email you when your spot is ready.
            </p>
          </div>
        </section>
      </main>
    </div>
  );
}
