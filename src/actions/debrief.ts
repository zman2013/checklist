'use server';

import getDb from '@/lib/db.server';
import { revalidatePath } from 'next/cache';
import type { ActionResult } from './trips';

// ────────────────────────────────────────────────────────
// submitDebrief: 提交行程后复盘
// ────────────────────────────────────────────────────────
export async function submitDebrief(
  tripId: number,
  forgotten: string[],  // 忘带物品
  surplus: string[]     // 带多了
): Promise<ActionResult> {
  try {
    const db = getDb();

    const trip = db
      .prepare('SELECT id, template_id, status FROM trips WHERE id = ?')
      .get(tripId) as { id: number; template_id: number; status: string } | undefined;

    if (!trip) {
      return { ok: false, error: '行程不存在' };
    }

    // Manual upsert: check existing then increment or insert
    const findItem = db.prepare(
      'SELECT id FROM forgotten_items WHERE template_id = ? AND lower(text) = lower(?) AND item_type = ?'
    );
    const incrementItem = db.prepare(
      'UPDATE forgotten_items SET times_forgotten = times_forgotten + 1 WHERE id = ?'
    );
    const insertItem = db.prepare(
      'INSERT INTO forgotten_items (template_id, text, times_forgotten, item_type) VALUES (?, ?, 1, ?)'
    );

    const debrief = db.transaction(() => {
      // Upsert forgotten items
      for (const text of forgotten) {
        const trimmed = text.trim();
        if (!trimmed) continue;
        const existing = findItem.get(trip.template_id, trimmed, 'forgotten') as { id: number } | undefined;
        if (existing) {
          incrementItem.run(existing.id);
        } else {
          insertItem.run(trip.template_id, trimmed, 'forgotten');
        }
      }

      // Upsert surplus items
      for (const text of surplus) {
        const trimmed = text.trim();
        if (!trimmed) continue;
        const existing = findItem.get(trip.template_id, trimmed, 'surplus') as { id: number } | undefined;
        if (existing) {
          incrementItem.run(existing.id);
        } else {
          insertItem.run(trip.template_id, trimmed, 'surplus');
        }
      }

      // Mark trip as completed
      db.prepare(`UPDATE trips SET status = 'completed', end_date = date('now') WHERE id = ?`).run(tripId);
    });

    debrief();
    revalidatePath('/');
    revalidatePath(`/trips/${tripId}`);
    return { ok: true, data: undefined };
  } catch {
    return { ok: false, error: '保存失败，请重试' };
  }
}
