'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  DragEndEvent,
} from '@dnd-kit/core';
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import {
  addTemplateItem,
  updateTemplateItem,
  deleteTemplateItem,
  reorderTemplateItems,
  deleteTemplate,
} from '@/actions/templates';

interface TemplateItem {
  id: number;
  text: string;
  category: string;
  sort_order: number;
}

interface TemplateEditClientProps {
  templateId: number;
  templateName: string;
  templateIcon: string;
  items: TemplateItem[];
}

// Sortable item wrapper
function SortableItem({
  item,
  onUpdate,
  onDelete,
}: {
  item: TemplateItem;
  onUpdate: (id: number, text: string) => void;
  onDelete: (id: number) => void;
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } =
    useSortable({ id: item.id });

  const [editing, setEditing] = useState(false);
  const [editText, setEditText] = useState(item.text);

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
    background: isDragging ? '#f9f9f9' : 'white',
  };

  return (
    <div
      ref={setNodeRef}
      style={style}
      className="item-row"
    >
      {/* Drag handle */}
      <span
        {...attributes}
        {...listeners}
        style={{ cursor: isDragging ? 'grabbing' : 'grab', color: '#ccc', fontSize: 16, flexShrink: 0 }}
        aria-label="拖拽排序"
      >
        ⠿
      </span>

      {editing ? (
        <input
          className="input-field"
          value={editText}
          onChange={(e) => setEditText(e.target.value)}
          onBlur={() => {
            setEditing(false);
            if (editText.trim() !== item.text) onUpdate(item.id, editText.trim());
          }}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              setEditing(false);
              if (editText.trim() !== item.text) onUpdate(item.id, editText.trim());
            }
            if (e.key === 'Escape') {
              setEditing(false);
              setEditText(item.text);
            }
          }}
          autoFocus
          style={{ flex: 1, padding: '4px 8px' }}
        />
      ) : (
        <span
          className="item-text"
          onClick={() => setEditing(true)}
          style={{ cursor: 'text' }}
        >
          {item.text}
        </span>
      )}

      <button
        onClick={() => onDelete(item.id)}
        style={{
          background: 'none',
          border: 'none',
          color: '#ccc',
          cursor: 'pointer',
          fontSize: 18,
          padding: '0 4px',
          flexShrink: 0,
        }}
        aria-label={`删除 ${item.text}`}
      >
        ×
      </button>
    </div>
  );
}

export default function TemplateEditClient({
  templateId,
  templateName,
  templateIcon,
  items: initialItems,
}: TemplateEditClientProps) {
  const router = useRouter();
  const [items, setItems] = useState(initialItems);
  const [newCategory, setNewCategory] = useState(
    initialItems.length > 0 ? initialItems[initialItems.length - 1].category : '基础'
  );
  const [newText, setNewText] = useState('');
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [toast, setToast] = useState('');
  const [loading, setLoading] = useState(false);

  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  );

  function showMsg(msg: string) {
    setToast(msg);
    setTimeout(() => setToast(''), 3000);
  }

  async function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over || active.id === over.id) return;

    const oldIndex = items.findIndex((i) => i.id === active.id);
    const newIndex = items.findIndex((i) => i.id === over.id);
    const reordered = arrayMove(items, oldIndex, newIndex);
    setItems(reordered);

    const result = await reorderTemplateItems(templateId, reordered.map((i) => i.id));
    if (!result.ok) showMsg(result.error);
  }

  async function handleAdd() {
    if (!newText.trim()) return;
    setLoading(true);
    const result = await addTemplateItem(templateId, newCategory, newText.trim());
    setLoading(false);
    if (!result.ok) {
      showMsg(result.error);
      return;
    }
    setItems([
      ...items,
      {
        id: result.data.itemId,
        text: newText.trim(),
        category: newCategory,
        sort_order: items.filter((i) => i.category === newCategory).length,
      },
    ]);
    setNewText('');
  }

  async function handleUpdate(id: number, text: string) {
    if (!text) return;
    const result = await updateTemplateItem(id, text);
    if (!result.ok) {
      showMsg(result.error);
      return;
    }
    setItems(items.map((i) => (i.id === id ? { ...i, text } : i)));
  }

  async function handleDelete(id: number) {
    const result = await deleteTemplateItem(id);
    if (!result.ok) {
      showMsg(result.error);
      return;
    }
    setItems(items.filter((i) => i.id !== id));
  }

  async function handleDeleteTemplate() {
    setLoading(true);
    const result = await deleteTemplate(templateId);
    setLoading(false);
    if (!result.ok) {
      showMsg(result.error);
      setShowDeleteConfirm(false);
      return;
    }
    router.push('/templates');
  }

  // Get unique categories in order
  const categories = Array.from(new Set(items.map((i) => i.category)));

  return (
    <div style={{ padding: '16px' }}>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 24 }}>
        <button
          onClick={() => router.push('/templates')}
          style={{ background: 'none', border: 'none', color: '#999', fontSize: 20, cursor: 'pointer', padding: 0 }}
          aria-label="返回"
        >
          ←
        </button>
        <h1 className="page-title" style={{ margin: 0 }}>
          {templateIcon} {templateName}
        </h1>
      </div>

      {/* Items list with drag-and-drop */}
      {categories.length === 0 ? (
        <div style={{ padding: '24px 0', textAlign: 'center', color: '#999', fontSize: 14 }}>
          还没有条目<br />
          <span style={{ fontSize: 12 }}>在下方添加第一条</span>
        </div>
      ) : (
        <DndContext
          sensors={sensors}
          collisionDetection={closestCenter}
          onDragEnd={handleDragEnd}
        >
          <SortableContext
            items={items.map((i) => i.id)}
            strategy={verticalListSortingStrategy}
          >
            {categories.map((cat) => (
              <section key={cat} style={{ marginBottom: 16 }}>
                <div className="section-label" style={{ padding: '0 0 4px' }}>{cat}</div>
                {items
                  .filter((i) => i.category === cat)
                  .map((item) => (
                    <SortableItem
                      key={item.id}
                      item={item}
                      onUpdate={handleUpdate}
                      onDelete={handleDelete}
                    />
                  ))}
              </section>
            ))}
          </SortableContext>
        </DndContext>
      )}

      {/* Add item form */}
      <div
        style={{
          marginTop: 24,
          padding: 16,
          border: '1px solid var(--border)',
          borderRadius: 6,
          background: 'white',
        }}
      >
        <div className="section-label" style={{ padding: '0 0 12px' }}>添加条目</div>
        <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
          <input
            className="input-field"
            placeholder="分组（如：文件、电子设备）"
            value={newCategory}
            onChange={(e) => setNewCategory(e.target.value)}
            style={{ flex: 1 }}
          />
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <input
            className="input-field"
            placeholder="条目名称"
            value={newText}
            onChange={(e) => setNewText(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter') handleAdd(); }}
            style={{ flex: 1 }}
          />
          <button
            onClick={handleAdd}
            disabled={loading || !newText.trim()}
            style={{
              padding: '10px 16px',
              background: '#1a1a1a',
              color: 'white',
              border: 'none',
              borderRadius: 4,
              cursor: 'pointer',
              fontSize: 18,
              flexShrink: 0,
            }}
            aria-label="添加条目"
          >
            +
          </button>
        </div>
      </div>

      {/* Delete template section */}
      <div style={{ marginTop: 40, paddingTop: 24, borderTop: '1px solid var(--border)' }}>
        {!showDeleteConfirm ? (
          <button
            className="btn-danger"
            onClick={() => setShowDeleteConfirm(true)}
          >
            删除此行程类型
          </button>
        ) : (
          <div
            style={{
              padding: 16,
              border: '1px solid var(--danger)',
              borderRadius: 6,
              background: '#fff5f5',
            }}
          >
            <p style={{ fontSize: 13, marginBottom: 12, color: '#1a1a1a' }}>
              确认删除？这会删除该类型的所有条目，无法恢复。
            </p>
            <div style={{ display: 'flex', gap: 8 }}>
              <button
                className="btn-danger"
                onClick={handleDeleteTemplate}
                disabled={loading}
              >
                {loading ? '删除中...' : '确认删除'}
              </button>
              <button
                onClick={() => setShowDeleteConfirm(false)}
                style={{
                  padding: '8px 16px',
                  background: 'white',
                  border: '1px solid var(--border)',
                  borderRadius: 4,
                  cursor: 'pointer',
                  fontSize: 12,
                }}
              >
                取消
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Toast */}
      {toast && (
        <div className="toast" role="alert">{toast}</div>
      )}

      <div style={{ height: 32 }} />
    </div>
  );
}
