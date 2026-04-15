// Packing page — Server Component
import getDb from '@/lib/db.server';
import PackingClient from '@/components/PackingClient';
import Link from 'next/link';
import { notFound } from 'next/navigation';

export const dynamic = 'force-dynamic';

interface PageProps {
  params: { id: string };
}

export default function TripPage({ params }: PageProps) {
  const tripId = parseInt(params.id, 10);
  if (isNaN(tripId)) notFound();

  const db = getDb();

  type TripRow = {
    id: number;
    template_id: number;
    destination: string | null;
    status: string;
    template_name: string;
    template_icon: string;
  };
  const trip = db
    .prepare(`
      SELECT t.id, t.template_id, t.destination, t.status,
             tt.name as template_name, tt.icon as template_icon
      FROM trips t
      JOIN trip_templates tt ON tt.id = t.template_id
      WHERE t.id = ?
    `)
    .get(tripId) as TripRow | undefined;

  if (!trip) notFound();

  // Load regular (non-ad-hoc) trip_items joined with template_items
  type RegularRow = {
    trip_item_id: number;
    text: string;
    category: string;
    checked_at: string | null;
    sort_order: number;
  };
  const regularRows = db
    .prepare(`
      SELECT
        ti.id as trip_item_id,
        tmi.text as text,
        tmi.category as category,
        ti.checked_at,
        tmi.sort_order as sort_order
      FROM trip_items ti
      JOIN template_items tmi ON tmi.id = ti.item_id
      WHERE ti.trip_id = ? AND ti.is_ad_hoc = 0
      ORDER BY tmi.category, tmi.sort_order
    `)
    .all(tripId) as RegularRow[];

  // Load ad-hoc trip_items (以往忘带 items)
  type AdHocRow = {
    trip_item_id: number;
    text: string;
    checked_at: string | null;
    times_forgotten: number;
  };
  const adHocRows = db
    .prepare(`
      SELECT
        ti.id as trip_item_id,
        ti.text as text,
        ti.checked_at,
        COALESCE(fi.times_forgotten, 1) as times_forgotten
      FROM trip_items ti
      LEFT JOIN forgotten_items fi
        ON lower(fi.text) = lower(ti.text)
        AND fi.template_id = ?
        AND fi.item_type = 'forgotten'
      WHERE ti.trip_id = ? AND ti.is_ad_hoc = 1
      ORDER BY times_forgotten DESC
    `)
    .all(trip.template_id, tripId) as AdHocRow[];

  // Group regular items by category
  const categoryMap = new Map<string, { id: number; text: string; checked: boolean }[]>();
  let checkedCount = 0;

  for (const row of regularRows) {
    if (row.checked_at) checkedCount++;
    if (!categoryMap.has(row.category)) categoryMap.set(row.category, []);
    categoryMap.get(row.category)!.push({
      id: row.trip_item_id,
      text: row.text,
      checked: !!row.checked_at,
    });
  }

  const groups = Array.from(categoryMap.entries()).map(([category, items]) => ({
    category,
    items,
  }));

  const forgottenGroup = adHocRows.map((row) => {
    if (row.checked_at) checkedCount++;
    return {
      id: row.trip_item_id,
      text: row.text,
      checked: !!row.checked_at,
      forgotCount: row.times_forgotten,
    };
  });

  const totalCount = regularRows.length + adHocRows.length;

  const tripTitle = trip.destination
    ? `${trip.template_name} · ${trip.destination}`
    : trip.template_name;

  return (
    <main>
      {/* Header */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 8,
          padding: '16px 16px 12px',
          borderBottom: '1px solid var(--border)',
        }}
      >
        <Link
          href="/"
          aria-label="返回首页"
          style={{ color: '#999', fontSize: 20, textDecoration: 'none', flexShrink: 0 }}
        >
          ←
        </Link>
        <h1
          className="page-title"
          style={{ fontSize: 15, margin: 0, flex: 1, textAlign: 'center' }}
        >
          {tripTitle}
        </h1>
        <div style={{ width: 28 }} />
      </div>

      <PackingClient
        tripId={tripId}
        tripName={trip.template_name}
        destination={trip.destination}
        status={trip.status}
        groups={groups}
        forgottenGroup={forgottenGroup}
        totalCount={totalCount}
        checkedCount={checkedCount}
      />

      <div style={{ height: 100 }} />
    </main>
  );
}
