import { useCallback, useEffect, useState } from 'react';
import {
  DndContext,
  PointerSensor,
  KeyboardSensor,
  useSensor,
  useSensors,
  closestCorners,
  DragOverlay,
  defaultDropAnimationSideEffects,
} from '@dnd-kit/core';
import type { DragEndEvent, DragOverEvent, DragStartEvent } from '@dnd-kit/core';
import { sortableKeyboardCoordinates } from '@dnd-kit/sortable';
import { Quadrant as QuadrantComponent } from './Quadrant';
import { TaskCard } from './TaskCard';
import { BulkActions } from './BulkActions';
import { useTaskStore } from '../store/useTaskStore';
import type { Quadrant, Task } from '../types';

export function Matrix() {
  const { moveTask, reorderTasks, clearSelection, undo, selectedIds, tasks } = useTaskStore();
  const [activeTask, setActiveTask] = useState<Task | null>(null);

  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: { distance: 5 },
    }),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  );

  // Global keyboard handler
  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      // Undo
      if ((e.metaKey || e.ctrlKey) && e.key === 'z') {
        e.preventDefault();
        undo();
        return;
      }

      // Escape clears selection
      if (e.key === 'Escape') {
        clearSelection();
        return;
      }
    }

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [undo, clearSelection]);

  function handleDragStart(event: DragStartEvent) {
    const task = tasks.find(t => t.id === event.active.id);
    if (task) setActiveTask(task);
  }

  const handleDragOver = useCallback((event: DragOverEvent) => {
    const { active, over } = event;
    if (!over) return;

    const activeId = active.id as string;
    const overId = over.id as string;

    // Over a quadrant drop zone
    if (overId.startsWith('quadrant-')) {
      const quadrant = parseInt(overId.replace('quadrant-', '')) as Quadrant;
      const activeTask = tasks.find(t => t.id === activeId);
      if (activeTask && activeTask.quadrant !== quadrant) {
        moveTask(activeId, quadrant);
      }
    }
  }, [tasks, moveTask]);

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    setActiveTask(null);

    if (!over) return;

    const activeId = active.id as string;
    const overId = over.id as string;

    if (overId.startsWith('quadrant-')) {
      const quadrant = parseInt(overId.replace('quadrant-', '')) as Quadrant;
      moveTask(activeId, quadrant);
      return;
    }

    // Reordering within same quadrant
    if (activeId !== overId) {
      const activeTask = tasks.find(t => t.id === activeId);
      const overTask = tasks.find(t => t.id === overId);
      if (activeTask && overTask && activeTask.quadrant === overTask.quadrant) {
        reorderTasks(activeTask.quadrant, activeId, overId);
      } else if (activeTask && overTask && activeTask.quadrant !== overTask.quadrant) {
        moveTask(activeId, overTask.quadrant);
      }
    }
  }

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCorners}
      onDragStart={handleDragStart}
      onDragOver={handleDragOver}
      onDragEnd={handleDragEnd}
    >
      <div className="grid grid-cols-2 gap-4 flex-1 min-h-0">
        {([1, 2, 3, 4] as Quadrant[]).map(q => (
          <QuadrantComponent key={q} quadrant={q} />
        ))}
      </div>

      <DragOverlay
        dropAnimation={{
          sideEffects: defaultDropAnimationSideEffects({
            styles: { active: { opacity: '0.4' } },
          }),
        }}
      >
        {activeTask && (
          <div className="opacity-95 rotate-1 scale-105">
            <TaskCard task={activeTask} />
          </div>
        )}
      </DragOverlay>

      {selectedIds.size > 1 && <BulkActions />}
    </DndContext>
  );
}
