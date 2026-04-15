// Templates list page
import getDb from '@/lib/db.server';
import Link from 'next/link';

export const dynamic = 'force-dynamic';

export default function TemplatesPage() {
  const db = getDb();

  const templates = db
    .prepare('SELECT id, name, icon, use_count FROM trip_templates ORDER BY use_count DESC, id ASC')
    .all() as { id: number; name: string; icon: string; use_count: number }[];

  return (
    <main style={{ padding: '16px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 24 }}>
        <Link
          href="/"
          aria-label="返回首页"
          style={{ color: '#999', fontSize: 20, textDecoration: 'none' }}
        >
          ←
        </Link>
        <h1 className="page-title" style={{ margin: 0 }}>
          行程类型
        </h1>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {templates.map((t) => (
          <Link
            key={t.id}
            href={`/templates/${t.id}/edit`}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 12,
              padding: '14px 16px',
              border: '1px solid var(--border)',
              borderRadius: 6,
              background: 'white',
              textDecoration: 'none',
              color: 'var(--fg)',
            }}
          >
            <span style={{ fontSize: 24 }}>{t.icon}</span>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 15, fontWeight: 500 }}>{t.name}</div>
              {t.use_count > 0 && (
                <div className="helper-text" style={{ marginTop: 2 }}>
                  已使用 {t.use_count} 次
                </div>
              )}
            </div>
            <span style={{ color: '#ccc', fontSize: 18 }}>→</span>
          </Link>
        ))}
      </div>

      <div style={{ marginTop: 24 }}>
        <Link href="/templates/new" style={{ textDecoration: 'none' }}>
          <button className="btn-secondary">+ 新建行程类型</button>
        </Link>
      </div>
    </main>
  );
}
