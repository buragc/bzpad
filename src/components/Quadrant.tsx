import { useState } from 'react';
import { useDroppable } from '@dnd-kit/core';
import { SortableContext, verticalListSortingStrategy } from '@dnd-kit/sortable';
import type { Quadrant as QuadrantType } from '../types';
import { QUADRANT_CONFIG } from '../types';
import { useTaskStore } from '../store/useTaskStore';
import { TaskCard } from './TaskCard';
import { QuickAdd } from './QuickAdd';

interface QuadrantProps {
  quadrant: QuadrantType;
}

export function Quadrant({ quadrant }: QuadrantProps) {
  const [adding, setAdding] = useState(false);
  const [collapsed, setCollapsed] = useState(false);

  const tasks = useTaskStore(s => s.getTasksByQuadrant(quadrant));
  const filter = useTaskStore(s => s.filter);
  const getFilteredTasks = useTaskStore(s => s.getFilteredTasks);
  const focusedId = useTaskStore(s => s.focusedId);

  const config = QUADRANT_CONFIG[quadrant];
  const filteredTasks = getFilteredTasks(tasks);
  const taskIds = filteredTasks.map(t => t.id);

  const { setNodeRef, isOver } = useDroppable({
    id: `quadrant-${quadrant}`,
    data: { quadrant },
  });

  const hasFilter = filter.search || filter.quadrants.length > 0 || filter.tags.length > 0;

  return (
    <div className={`flex flex-col rounded-xl border-2 overflow-hidden transition-colors ${config.borderColor} ${isOver ? 'ring-2 ring-blue-400 ring-offset-1 dark:ring-offset-gray-950' : ''}`}>
      {/* Header */}
      <div className={`${config.headerBg} px-4 py-3 flex items-center justify-between shrink-0`}>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setCollapsed(c => !c)}
            className="p-0.5 rounded hover:bg-black/10 dark:hover:bg-white/10 transition-colors"
            aria-label={collapsed ? 'Expand' : 'Collapse'}
          >
            <svg
              className={`w-3.5 h-3.5 ${config.color} transition-transform ${collapsed ? '' : 'rotate-90'}`}
              fill="currentColor"
              viewBox="0 0 20 20"
            >
              <path fillRule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clipRule="evenodd" />
            </svg>
          </button>
          <div>
            <div className={`font-semibold text-sm leading-tight ${config.color}`}>
              {config.label}
            </div>
            <div className="text-xs text-gray-500 dark:text-gray-400">{config.subtitle}</div>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <span className="text-xs font-medium text-gray-500 dark:text-gray-400 tabular-nums">
            {filteredTasks.length}{hasFilter && tasks.length !== filteredTasks.length ? `/${tasks.length}` : ''}
          </span>
          <button
            onClick={() => setAdding(a => !a)}
            className={`p-1 rounded transition-colors ${config.color} hover:bg-black/10 dark:hover:bg-white/10`}
            aria-label="Add task"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
            </svg>
          </button>
        </div>
      </div>

      {!collapsed && (
        <div
          ref={setNodeRef}
          className={`flex-1 overflow-y-auto p-3 space-y-2 min-h-[120px] transition-colors ${isOver ? 'bg-blue-50/50 dark:bg-blue-950/20' : 'bg-white/50 dark:bg-gray-900/50'}`}
          style={{ scrollbarWidth: 'thin' }}
        >
          {/* Inline quick add */}
          {adding && (
            <QuickAdd
              defaultQuadrant={quadrant}
              autoFocus
              onDone={() => setAdding(false)}
              placeholder={`Add to ${config.label}…`}
            />
          )}

          <SortableContext items={taskIds} strategy={verticalListSortingStrategy}>
            {filteredTasks.map(task => (
              <TaskCard
                key={task.id}
                task={task}
                isFocused={focusedId === task.id}
              />
            ))}
          </SortableContext>

          {filteredTasks.length === 0 && !adding && (
            <div className="flex flex-col items-center justify-center py-8 text-gray-400 dark:text-gray-600 text-sm gap-2">
              <svg className="w-8 h-8 opacity-40" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
              </svg>
              {hasFilter ? 'No matching tasks' : 'No tasks yet'}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
