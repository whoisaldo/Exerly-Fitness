import { LandingNav } from './landing/LandingNav';
import { Hero } from './landing/Hero';
import { DemoSection } from './landing/DemoSection';
import { StatsBand } from './landing/StatsBand';
import { FeaturesGrid } from './landing/FeaturesGrid';
import { PlatformSection } from './landing/PlatformSection';
import { Testimonials } from './landing/Testimonials';
import { CTASection } from './landing/CTASection';
import { Footer } from './landing/Footer';

export default function LandingPage() {
  return (
    <div className="min-h-screen overflow-x-hidden bg-deep text-slate-100">
      <LandingNav />
      <main>
        <Hero />
        <DemoSection />
        <StatsBand />
        <FeaturesGrid />
        <PlatformSection />
        <Testimonials />
        <CTASection />
      </main>
      <Footer />
    </div>
  );
}
