'use client';

import { useState } from 'react';
import { AnimatePresence } from 'framer-motion';
import CreateTripDialog from './CreateTripDialog';
import Link from 'next/link';

interface Template {
  id: number;
  name: string;
  icon: string;
  useCount: number;
}

interface ActiveTrip {
  id: number;
  templateName: string;
  destination: string | null;
  checkedCount: number;
  totalCount: number;
}

interface HomeClientProps {
  templates: Template[];
  activeTrips: ActiveTrip[];
}

export default function HomeClient({ templates, activeTrips }: HomeClientProps) {
  const [selectedTemplate, setSelectedTemplate] = useState<Template | null>(null);

  return (
    <>
      {/* Active trips */}
      {activeTrips.length > 0 && (
        <div style={{ padding: '16px 16px 0' }}>
          {activeTrips.map((trip) => {
            const pct = trip.totalCount > 0
              ? Math.round((trip.checkedCount / trip.totalCount) * 100)
              : 0;
            const label = trip.destination
              ? `${trip.templateName} · ${trip.destination}`
              : trip.templateName;
            return (
              <Link
                key={trip.id}
                href={`/trips/${trip.id}`}
                className="active-trip-banner"
                aria-label={`继续 ${label}，已完成 ${pct}%`}
                style={{ marginBottom: 8, display: 'flex' }}
              >
                <div>
                  <div style={{ fontWeight: 500, fontSize: 14 }}>{label}</div>
                  <div style={{ fontSize: 12, opacity: 0.7, marginTop: 2 }}>
                    继续打包 · {pct}% 已完成
                  </div>
                </div>
                <span style={{ fontSize: 18 }}>→</span>
              </Link>
            );
          })}
        </div>
      )}

      {/* Template grid */}
      <div style={{ padding: activeTrips.length > 0 ? '16px' : '24px 16px 16px' }}>
        {activeTrips.length === 0 && (
          <h1
            className="page-title"
            style={{ textAlign: 'center', marginBottom: 24 }}
          >
            Pack
          </h1>
        )}

        <div
          style={{
            display: 'grid',
            gridTemplateColumns: '1fr 1fr',
            gap: 8,
          }}
        >
          {templates.map((tpl) => (
            <button
              key={tpl.id}
              className="template-card"
              onClick={() => setSelectedTemplate(tpl)}
              role="button"
              aria-label={`${tpl.name}，已使用 ${tpl.useCount} 次`}
            >
              <span style={{ fontSize: 28 }}>{tpl.icon}</span>
              <span style={{ fontSize: 14, fontWeight: 500, color: '#1a1a1a' }}>
                {tpl.name}
              </span>
              {tpl.useCount > 0 && (
                <span className="helper-text">已使用 {tpl.useCount} 次</span>
              )}
            </button>
          ))}
        </div>
      </div>

      {/* Bottom nav */}
      <div style={{ padding: '0 16px 32px', textAlign: 'center' }}>
        <Link
          href="/templates/new"
          style={{ fontSize: 13, color: '#999', textDecoration: 'none' }}
        >
          + 新建行程类型
        </Link>
      </div>

      {/* Create trip dialog */}
      <AnimatePresence>
        {selectedTemplate && (
          <CreateTripDialog
            key={selectedTemplate.id}
            templateId={selectedTemplate.id}
            templateName={selectedTemplate.name}
            onClose={() => setSelectedTemplate(null)}
          />
        )}
      </AnimatePresence>
    </>
  );
}
