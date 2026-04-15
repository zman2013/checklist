// Home page — Server Component
import getDb from '@/lib/db.server';
import HomeClient from '@/components/HomeClient';
import Link from 'next/link';

export const dynamic = 'force-dynamic';

export default function HomePage() {
  const db = getDb();

  const templates = db
    .prepare('SELECT id, name, icon, use_count FROM trip_templates ORDER BY use_count DESC, id ASC')
    .all() as { id: number; name: string; icon: string; use_count: number }[];

  type ActiveRow = { id: number; template_name: string; destination: string | null };
  const activeTripRows = db
    .prepare(`
      SELECT t.id, tt.name as template_name, t.destination
      FROM trips t
      JOIN trip_templates tt ON tt.id = t.template_id
      WHERE t.status IN ('packing', 'departed')
      ORDER BY t.id DESC
    `)
    .all() as ActiveRow[];

  const activeTrips = activeTripRows.map((row) => {
    const counts = db
      .prepare(
        'SELECT COUNT(*) as total, COUNT(checked_at) as checked FROM trip_items WHERE trip_id = ?'
      )
      .get(row.id) as { total: number; checked: number };
    return {
      id: row.id,
      templateName: row.template_name,
      destination: row.destination,
      checkedCount: counts.checked,
      totalCount: counts.total,
    };
  });

  return (
    <main>
      <div style={{ display: 'flex', justifyContent: 'flex-end', padding: '16px 16px 0' }}>
        <Link
          href="/templates"
          aria-label="管理行程类型"
          style={{ color: '#bbb', fontSize: 18, textDecoration: 'none' }}
        >
          ⚙
        </Link>
      </div>

      <HomeClient
        templates={templates.map((t) => ({
          id: t.id,
          name: t.name,
          icon: t.icon,
          useCount: t.use_count,
        }))}
        activeTrips={activeTrips}
      />
    </main>
  );
}
