'use server';

import getDb from '@/lib/db.server';
import { revalidatePath } from 'next/cache';

export type ActionResult<T = void> =
  | { ok: true; data: T }
  | { ok: false; error: string };

// ────────────────────────────────────────────────────────
// createTrip: 从模板创建一次出行（事务）
// ────────────────────────────────────────────────────────
export async function createTrip(
  templateId: number,
  destination?: string
): Promise<ActionResult<{ tripId: number }>> {
  try {
    const db = getDb();

    // Verify template exists
    const template = db
      .prepare('SELECT id FROM trip_templates WHERE id = ?')
      .get(templateId);
    if (!template) {
      return { ok: false, error: '行程类型不存在' };
    }

    const create = db.transaction(() => {
      // 1. INSERT trip
      const trip = db
        .prepare(
          `INSERT INTO trips (template_id, destination, start_date, status)
           VALUES (?, ?, date('now'), 'packing')`
        )
        .run(templateId, destination ?? null);
      const tripId = trip.lastInsertRowid as number;

      // 2. Copy all template items to trip_items
      const items = db
        .prepare('SELECT id FROM template_items WHERE template_id = ?')
        .all(templateId) as { id: number }[];

      const insertTripItem = db.prepare(
        `INSERT INTO trip_items (trip_id, item_id, text, is_ad_hoc, checked_at)
         VALUES (?, ?, NULL, 0, NULL)`
      );
      for (const item of items) {
        insertTripItem.run(tripId, item.id);
      }

      // 3. Copy forgotten_items as is_ad_hoc trip_items so they have IDs for toggle
      const forgottenItems = db
        .prepare(
          `SELECT text FROM forgotten_items WHERE template_id = ? AND item_type = 'forgotten' ORDER BY times_forgotten DESC`
        )
        .all(templateId) as { text: string }[];

      const insertForgottenTripItem = db.prepare(
        `INSERT INTO trip_items (trip_id, item_id, text, is_ad_hoc, checked_at)
         VALUES (?, NULL, ?, 1, NULL)`
      );
      for (const fi of forgottenItems) {
        insertForgottenTripItem.run(tripId, fi.text);
      }

      // 4. Increment use_count
      db.prepare('UPDATE trip_templates SET use_count = use_count + 1 WHERE id = ?').run(
        templateId
      );

      return tripId;
    });

    const tripId = create() as number;
    revalidatePath('/');
    return { ok: true, data: { tripId } };
  } catch {
    return { ok: false, error: '创建行程失败，请重试' };
  }
}

// ────────────────────────────────────────────────────────
// toggleItem: 勾选 / 取消勾选条目
// ────────────────────────────────────────────────────────
export async function toggleItem(
  tripItemId: number,
  checked: boolean
): Promise<ActionResult> {
  try {
    const db = getDb();

    const item = db
      .prepare('SELECT id, trip_id FROM trip_items WHERE id = ?')
      .get(tripItemId) as { id: number; trip_id: number } | undefined;

    if (!item) {
      return { ok: false, error: '条目不存在' };
    }

    db.prepare(
      `UPDATE trip_items SET checked_at = ? WHERE id = ?`
    ).run(checked ? new Date().toISOString() : null, tripItemId);

    revalidatePath(`/trips/${item.trip_id}`);
    return { ok: true, data: undefined };
  } catch {
    return { ok: false, error: '更新失败，请重试' };
  }
}

// ────────────────────────────────────────────────────────
// departTrip: 标记出发（status → 'departed'）
// ────────────────────────────────────────────────────────
export async function departTrip(tripId: number): Promise<ActionResult> {
  try {
    const db = getDb();
    db.prepare(
      `UPDATE trips SET status = 'departed' WHERE id = ? AND status = 'packing'`
    ).run(tripId);
    revalidatePath(`/trips/${tripId}`);
    return { ok: true, data: undefined };
  } catch {
    return { ok: false, error: '操作失败，请重试' };
  }
}
