'use server';

import getDb from '@/lib/db.server';
import { revalidatePath } from 'next/cache';
import type { ActionResult } from './trips';

// ────────────────────────────────────────────────────────
// createTemplate
// ────────────────────────────────────────────────────────
export async function createTemplate(
  name: string,
  icon: string
): Promise<ActionResult<{ templateId: number }>> {
  try {
    const db = getDb();
    const result = db
      .prepare('INSERT INTO trip_templates (name, icon, use_count) VALUES (?, ?, 0)')
      .run(name.trim(), icon.trim() || '🧳');
    revalidatePath('/');
    return { ok: true, data: { templateId: result.lastInsertRowid as number } };
  } catch {
    return { ok: false, error: '创建失败，请重试' };
  }
}

// ────────────────────────────────────────────────────────
// updateTemplate: 修改名称 / 图标
// ────────────────────────────────────────────────────────
export async function updateTemplate(
  templateId: number,
  name: string,
  icon: string
): Promise<ActionResult> {
  try {
    const db = getDb();
    db.prepare('UPDATE trip_templates SET name = ?, icon = ? WHERE id = ?').run(
      name.trim(),
      icon.trim() || '🧳',
      templateId
    );
    revalidatePath('/');
    revalidatePath(`/templates/${templateId}/edit`);
    return { ok: true, data: undefined };
  } catch {
    return { ok: false, error: '保存失败，请重试' };
  }
}

// ────────────────────────────────────────────────────────
// deleteTemplate: 删除模板（有进行中行程时阻止）
// ────────────────────────────────────────────────────────
export async function deleteTemplate(templateId: number): Promise<ActionResult> {
  try {
    const db = getDb();

    // Check for active trips
    const activeTrip = db
      .prepare(
        `SELECT id FROM trips WHERE template_id = ? AND status IN ('packing', 'departed') LIMIT 1`
      )
      .get(templateId) as { id: number } | undefined;

    if (activeTrip) {
      return { ok: false, error: '有进行中的行程，请先完成后再删除此类型' };
    }

    // Cascade delete template_items (foreign key ON DELETE CASCADE handles this)
    db.prepare('DELETE FROM trip_templates WHERE id = ?').run(templateId);
    revalidatePath('/');
    return { ok: true, data: undefined };
  } catch {
    return { ok: false, error: '删除失败，请重试' };
  }
}

// ────────────────────────────────────────────────────────
// addTemplateItem
// ────────────────────────────────────────────────────────
export async function addTemplateItem(
  templateId: number,
  category: string,
  text: string
): Promise<ActionResult<{ itemId: number }>> {
  try {
    const db = getDb();
    // Get max sort_order in this category
    const maxOrder = db
      .prepare(
        'SELECT MAX(sort_order) as m FROM template_items WHERE template_id = ? AND category = ?'
      )
      .get(templateId, category) as { m: number | null };
    const nextOrder = (maxOrder.m ?? -1) + 1;

    const result = db
      .prepare(
        'INSERT INTO template_items (template_id, category, text, sort_order) VALUES (?, ?, ?, ?)'
      )
      .run(templateId, category.trim(), text.trim(), nextOrder);

    revalidatePath(`/templates/${templateId}/edit`);
    return { ok: true, data: { itemId: result.lastInsertRowid as number } };
  } catch {
    return { ok: false, error: '添加失败，请重试' };
  }
}

// ────────────────────────────────────────────────────────
// updateTemplateItem
// ────────────────────────────────────────────────────────
export async function updateTemplateItem(
  itemId: number,
  text: string
): Promise<ActionResult> {
  try {
    const db = getDb();
    const item = db
      .prepare('SELECT template_id FROM template_items WHERE id = ?')
      .get(itemId) as { template_id: number } | undefined;
    if (!item) return { ok: false, error: '条目不存在' };
    db.prepare('UPDATE template_items SET text = ? WHERE id = ?').run(text.trim(), itemId);
    revalidatePath(`/templates/${item.template_id}/edit`);
    return { ok: true, data: undefined };
  } catch {
    return { ok: false, error: '保存失败，请重试' };
  }
}

// ────────────────────────────────────────────────────────
// deleteTemplateItem
// ────────────────────────────────────────────────────────
export async function deleteTemplateItem(itemId: number): Promise<ActionResult> {
  try {
    const db = getDb();
    const item = db
      .prepare('SELECT template_id FROM template_items WHERE id = ?')
      .get(itemId) as { template_id: number } | undefined;
    if (!item) return { ok: false, error: '条目不存在' };
    db.prepare('DELETE FROM template_items WHERE id = ?').run(itemId);
    revalidatePath(`/templates/${item.template_id}/edit`);
    return { ok: true, data: undefined };
  } catch {
    return { ok: false, error: '删除失败，请重试' };
  }
}

// ────────────────────────────────────────────────────────
// reorderTemplateItems: 拖拽排序后批量更新 sort_order
// ────────────────────────────────────────────────────────
export async function reorderTemplateItems(
  templateId: number,
  orderedIds: number[]  // item IDs in new order
): Promise<ActionResult> {
  try {
    const db = getDb();
    const update = db.prepare('UPDATE template_items SET sort_order = ? WHERE id = ? AND template_id = ?');
    const reorder = db.transaction(() => {
      orderedIds.forEach((id, index) => {
        update.run(index, id, templateId);
      });
    });
    reorder();
    revalidatePath(`/templates/${templateId}/edit`);
    return { ok: true, data: undefined };
  } catch {
    return { ok: false, error: '排序失败，请重试' };
  }
}
