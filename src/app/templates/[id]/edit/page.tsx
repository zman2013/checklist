// Template edit page
import getDb from '@/lib/db.server';
import TemplateEditClient from '@/components/TemplateEditClient';
import { notFound } from 'next/navigation';

export const dynamic = 'force-dynamic';

interface PageProps {
  params: { id: string };
}

export default function TemplateEditPage({ params }: PageProps) {
  const templateId = parseInt(params.id, 10);
  if (isNaN(templateId)) notFound();

  const db = getDb();

  const template = db
    .prepare('SELECT id, name, icon FROM trip_templates WHERE id = ?')
    .get(templateId) as { id: number; name: string; icon: string } | undefined;

  if (!template) notFound();

  const items = db
    .prepare(
      'SELECT id, text, category, sort_order FROM template_items WHERE template_id = ? ORDER BY category, sort_order'
    )
    .all(templateId) as {
      id: number;
      text: string;
      category: string;
      sort_order: number;
    }[];

  return (
    <main>
      <TemplateEditClient
        templateId={templateId}
        templateName={template.name}
        templateIcon={template.icon}
        items={items}
      />
    </main>
  );
}
