// lib/db.server.ts
// DB 客户端 — 仅在服务端使用，禁止在 Client Component 中 import
// 使用简单方案：每次 require 时 CREATE TABLE IF NOT EXISTS

import Database from 'better-sqlite3';
import path from 'path';

const DB_PATH = path.join(process.cwd(), 'data.db');

function getDb() {
  const db = new Database(DB_PATH);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  initSchema(db);
  return db;
}

function initSchema(db: Database.Database) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS trip_templates (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      name        TEXT    NOT NULL,
      icon        TEXT    NOT NULL DEFAULT '🧳',
      use_count   INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS template_items (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      template_id INTEGER NOT NULL REFERENCES trip_templates(id) ON DELETE CASCADE,
      category    TEXT    NOT NULL,
      text        TEXT    NOT NULL,
      sort_order  INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS trips (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      template_id INTEGER NOT NULL REFERENCES trip_templates(id),
      destination TEXT,
      start_date  TEXT,
      end_date    TEXT,
      status      TEXT    NOT NULL DEFAULT 'packing'
      -- status: 'packing' | 'departed' | 'completed'
    );

    CREATE TABLE IF NOT EXISTS trip_items (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      trip_id     INTEGER NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
      item_id     INTEGER REFERENCES template_items(id),  -- null for ad-hoc items
      text        TEXT,                                    -- for ad-hoc items
      is_ad_hoc   INTEGER NOT NULL DEFAULT 0,             -- 0=false, 1=true
      checked_at  TEXT                                    -- ISO timestamp or null
      -- constraint: item_id OR text must be non-null (enforced in application layer)
    );

    CREATE TABLE IF NOT EXISTS forgotten_items (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      template_id     INTEGER NOT NULL REFERENCES trip_templates(id),
      text            TEXT    NOT NULL,
      times_forgotten INTEGER NOT NULL DEFAULT 1,
      item_type       TEXT    NOT NULL DEFAULT 'forgotten'
      -- item_type: 'forgotten' | 'surplus'
    );
  `);

  // Seed default templates if none exist
  const count = (db.prepare('SELECT COUNT(*) as n FROM trip_templates').get() as { n: number }).n;
  if (count === 0) {
    seedDefaults(db);
  }
}

function seedDefaults(db: Database.Database) {
  const insertTemplate = db.prepare(
    'INSERT INTO trip_templates (name, icon, use_count) VALUES (?, ?, 0)'
  );
  const insertItem = db.prepare(
    'INSERT INTO template_items (template_id, category, text, sort_order) VALUES (?, ?, ?, ?)'
  );

  const seed = db.transaction(() => {
    // 商务出行
    const biz = insertTemplate.run('商务出行', '💼');
    const bizId = biz.lastInsertRowid as number;
    [
      ['文件', '护照 / 身份证', 0],
      ['文件', '名片', 1],
      ['文件', '酒店确认单', 2],
      ['文件', '出差申请单', 3],
      ['电子设备', '笔记本电脑', 0],
      ['电子设备', '电脑充电器', 1],
      ['电子设备', '充电宝', 2],
      ['电子设备', '数据线', 3],
      ['电子设备', '耳机', 4],
      ['衣物', '正装衬衫 ×3', 0],
      ['衣物', '西裤 ×2', 1],
      ['衣物', '正装鞋', 2],
      ['衣物', '袜子 ×4', 3],
      ['洗漱', '牙刷牙膏', 0],
      ['洗漱', '洗面奶', 1],
      ['洗漱', '剃须刀', 2],
    ].forEach(([cat, text, order]) => {
      insertItem.run(bizId, cat, text, order);
    });

    // 度假
    const vacation = insertTemplate.run('度假', '🏖️');
    const vacId = vacation.lastInsertRowid as number;
    [
      ['证件', '护照', 0],
      ['证件', '签证（如需）', 1],
      ['证件', '行程单 / 酒店预订', 2],
      ['衣物', '换洗衣物', 0],
      ['衣物', '泳衣', 1],
      ['衣物', '拖鞋 / 凉鞋', 2],
      ['衣物', '防晒衣', 3],
      ['日用', '防晒霜', 0],
      ['日用', '太阳镜', 1],
      ['日用', '充电宝', 2],
      ['日用', '相机 / 手机支架', 3],
    ].forEach(([cat, text, order]) => {
      insertItem.run(vacId, cat, text, order);
    });

    // 周末短途
    const weekend = insertTemplate.run('周末短途', '🚗');
    const wkId = weekend.lastInsertRowid as number;
    [
      ['基础', '身份证', 0],
      ['基础', '手机充电器', 1],
      ['基础', '充电宝', 2],
      ['衣物', '换洗衣物 ×2', 0],
      ['衣物', '睡衣', 1],
      ['衣物', '舒适鞋', 2],
      ['日用', '牙刷牙膏', 0],
      ['日用', '洗漱用品', 1],
    ].forEach(([cat, text, order]) => {
      insertItem.run(wkId, cat, text, order);
    });

    // 徒步
    const hiking = insertTemplate.run('徒步', '🥾');
    const hikId = hiking.lastInsertRowid as number;
    [
      ['装备', '徒步鞋', 0],
      ['装备', '登山杖', 1],
      ['装备', '背包', 2],
      ['装备', '头灯', 3],
      ['衣物', '速干衣', 0],
      ['衣物', '冲锋衣', 1],
      ['衣物', '防晒帽', 2],
      ['衣物', '手套', 3],
      ['补给', '能量棒 ×5', 0],
      ['补给', '水壶（2L）', 1],
      ['补给', '急救包', 2],
      ['证件', '身份证', 0],
      ['证件', '紧急联系人信息', 1],
    ].forEach(([cat, text, order]) => {
      insertItem.run(hikId, cat, text, order);
    });
  });

  seed();
}

export default getDb;
