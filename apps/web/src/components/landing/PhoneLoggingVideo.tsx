import { useEffect, useRef, useState } from 'react';

const media = '/media/exerly-phone-logging';

export function PhoneLoggingVideo() {
  const [variant, setVariant] = useState<'landscape' | 'portrait' | null>(null);
  const [failed, setFailed] = useState(false);
  const video = useRef<HTMLVideoElement>(null);
  const selectedMedia = `${media}${variant === 'portrait' ? '-portrait' : ''}`;
  const aspect =
    variant === 'portrait'
      ? 'aspect-[9/16]'
      : variant === 'landscape'
        ? 'aspect-video'
        : 'aspect-[9/16] sm:aspect-video';

  useEffect(() => {
    if (variant) void video.current?.play().catch(() => {});
  }, [variant]);

  return (
    <figure className="mx-auto max-w-5xl">
      <div
        className={`relative ${aspect} overflow-hidden rounded-2xl border border-white/10 bg-deep`}
      >
        {variant ? (
          <video
            ref={video}
            className="h-full w-full"
            controls
            playsInline
            preload="none"
            src={`${selectedMedia}.mp4`}
            poster={`${selectedMedia}.jpg`}
            aria-label="Exerly iPhone food logging preview"
            aria-describedby="phone-video-description"
            onError={() => setFailed(true)}
          >
            <track kind="captions" src={`${media}.vtt`} srcLang="en" label="English" />
            <a href={`${selectedMedia}.mp4`}>Download the iPhone logging video</a>
          </video>
        ) : (
          <button
            type="button"
            className="group relative block h-full w-full focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-primary-bright"
            onClick={() =>
              setVariant(window.matchMedia('(max-width: 639px)').matches ? 'portrait' : 'landscape')
            }
            aria-label="Play iPhone logging video, 21 seconds"
            aria-describedby="phone-video-description"
          >
            <picture>
              <source media="(max-width: 639px)" srcSet={`${media}-portrait.jpg`} />
              <img
                src={`${media}.jpg`}
                alt="Adjusting a meal portion in Exerly on iPhone"
                width={1920}
                height={1080}
                loading="lazy"
                className="h-full w-full object-cover"
              />
            </picture>
            <span className="absolute bottom-3 left-3 inline-flex min-h-11 items-center gap-3 rounded-full border border-white/20 bg-deep px-4 py-2 text-sm font-semibold text-slate-50 group-hover:bg-surface-3 sm:bottom-6 sm:left-6 sm:px-5">
              <svg className="size-4" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path d="M5 3.5v13l11-6.5z" />
              </svg>
              Watch iPhone demo <span className="font-normal text-slate-300">0:21</span>
            </span>
          </button>
        )}
      </div>
      <figcaption className="mt-4 space-y-2 text-sm text-slate-400">
        <p id="phone-video-description">
          iPhone app preview with demo data. Choose a recent meal, set your portion, and save it to
          your diary. Calories and macros update with your entry. Music only, no narration.
        </p>
        {failed && (
          <p role="status">
            The video could not load.{' '}
            <a className="text-primary-bright underline" href={`${selectedMedia}.mp4`}>
              Open the video directly
            </a>
            .
          </p>
        )}
      </figcaption>
    </figure>
  );
}
