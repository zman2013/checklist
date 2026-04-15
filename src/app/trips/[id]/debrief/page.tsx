// Debrief page
import getDb from '@/lib/db.server';
import DebriefForm from '@/components/DebriefForm';
import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';

export const dynamic = 'force-dynamic';

interface PageProps {
  params: { id: string };
}

export default function DebriefPage({ params }: PageProps) {
  const tripId = parseInt(params.id, 10);
  if (isNaN(tripId)) notFound();

  const db = getDb();

  type TripRow = { id: number; status: string; template_name: string };
  const trip = db
    .prepare(`
      SELECT t.id, t.status, tt.name as template_name
      FROM trips t
      JOIN trip_templates tt ON tt.id = t.template_id
      WHERE t.id = ?
    `)
    .get(tripId) as TripRow | undefined;

  if (!trip) notFound();

  // If already completed, redirect home
  if (trip.status === 'completed') {
    redirect('/');
  }

  return (
    <main>
      <div style={{ display: 'flex', padding: '16px 16px 0' }}>
        <Link
          href={`/trips/${tripId}`}
          style={{ color: '#999', fontSize: 20, textDecoration: 'none' }}
          aria-label="返回打包页"
        >
          ←
        </Link>
      </div>
      <DebriefForm tripId={tripId} tripName={trip.template_name} />
    </main>
  );
}
