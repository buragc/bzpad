import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { v4 as uuidv4 } from 'uuid';
import type { Task, Quadrant, FilterState, ViewMode } from '../types';
import { detectQuadrant, parseDueDate, extractTags } from '../lib/taskUtils';

interface HistoryEntry {
  tasks: Task[];
}

interface TaskStore {
  tasks: Task[];
  selectedIds: Set<string>;
  focusedId: string | null;
  viewMode: ViewMode;
  filter: FilterState;
  darkMode: 'system' | 'light' | 'dark';
  history: HistoryEntry[];
  historyIndex: number;
  editingId: string | null;

  // Task CRUD
  addTask: (title: string, quadrant?: Quadrant) => void;
  updateTask: (id: string, updates: Partial<Task>) => void;
  deleteTask: (id: string) => void;
  deleteTasks: (ids: string[]) => void;
  completeTask: (id: string) => void;
  archiveTasks: (ids: string[]) => void;
  restoreTask: (id: string) => void;
  moveTask: (id: string, quadrant: Quadrant) => void;
  moveTasks: (ids: string[], quadrant: Quadrant) => void;
  reorderTasks: (quadrant: Quadrant, activeId: string, overId: string) => void;

  // Selection
  selectTask: (id: string, mode?: 'single' | 'toggle' | 'range') => void;
  clearSelection: () => void;
  setFocused: (id: string | null) => void;

  // View
  setViewMode: (mode: ViewMode) => void;
  setFilter: (filter: Partial<FilterState>) => void;
  setDarkMode: (mode: 'system' | 'light' | 'dark') => void;
  setEditingId: (id: string | null) => void;

  // Undo
  undo: () => void;

  // Computed
  getTasksByQuadrant: (quadrant: Quadrant) => Task[];
  getArchivedTasks: () => Task[];
  getFilteredTasks: (tasks: Task[]) => Task[];
  getAllTags: () => string[];
}

function pushHistory(store: TaskStore, _tasks: Task[]): Partial<TaskStore> {
  const newHistory = store.history.slice(0, store.historyIndex + 1);
  newHistory.push({ tasks: [...store.tasks] });
  return {
    history: newHistory.slice(-50), // keep last 50 states
    historyIndex: newHistory.length - 1,
  };
}

export const useTaskStore = create<TaskStore>()(
  persist(
    (set, get) => ({
      tasks: [],
      selectedIds: new Set(),
      focusedId: null,
      viewMode: 'matrix',
      filter: {
        search: '',
        quadrants: [],
        tags: [],
        showCompleted: false,
      },
      darkMode: 'system',
      history: [],
      historyIndex: -1,
      editingId: null,

      addTask: (title, quadrant) => {
        const dueDate = parseDueDate(title);
        const detectedQuadrant = quadrant ?? detectQuadrant(title);
        const tags = extractTags(title);

        // Strip parsed date text from title (rough approach)
        let cleanTitle = title.replace(/#\w+/g, '').trim();

        const task: Task = {
          id: uuidv4(),
          title: cleanTitle,
          quadrant: detectedQuadrant,
          dueDate: dueDate ? dueDate.toISOString() : null,
          createdAt: new Date().toISOString(),
          completedAt: null,
          isArchived: false,
          tags,
          clusterId: null,
          metadata: {
            source: dueDate ? 'parsed' : 'manual',
          },
        };

        set(state => ({
          ...pushHistory(state as TaskStore, state.tasks),
          tasks: [...state.tasks, task],
        }));
      },

      updateTask: (id, updates) => {
        set(state => ({
          ...pushHistory(state as TaskStore, state.tasks),
          tasks: state.tasks.map(t => t.id === id ? { ...t, ...updates } : t),
        }));
      },

      deleteTask: (id) => {
        set(state => ({
          ...pushHistory(state as TaskStore, state.tasks),
          tasks: state.tasks.filter(t => t.id !== id),
          selectedIds: new Set([...state.selectedIds].filter(sid => sid !== id)),
          focusedId: state.focusedId === id ? null : state.focusedId,
        }));
      },

      deleteTasks: (ids) => {
        const idSet = new Set(ids);
        set(state => ({
          ...pushHistory(state as TaskStore, state.tasks),
          tasks: state.tasks.filter(t => !idSet.has(t.id)),
          selectedIds: new Set(),
          focusedId: null,
        }));
      },

      completeTask: (id) => {
        set(state => ({
          ...pushHistory(state as TaskStore, state.tasks),
          tasks: state.tasks.map(t =>
            t.id === id
              ? { ...t, completedAt: new Date().toISOString(), isArchived: true }
              : t
          ),
          selectedIds: new Set([...state.selectedIds].filter(sid => sid !== id)),
        }));
      },

      archiveTasks: (ids) => {
        const idSet = new Set(ids);
        set(state => ({
          ...pushHistory(state as TaskStore, state.tasks),
          tasks: state.tasks.map(t =>
            idSet.has(t.id) ? { ...t, isArchived: true, completedAt: t.completedAt ?? new Date().toISOString() } : t
          ),
          selectedIds: new Set(),
        }));
      },

      restoreTask: (id) => {
        set(state => ({
          ...pushHistory(state as TaskStore, state.tasks),
          tasks: state.tasks.map(t =>
            t.id === id ? { ...t, isArchived: false, completedAt: null } : t
          ),
        }));
      },

      moveTask: (id, quadrant) => {
        set(state => ({
          ...pushHistory(state as TaskStore, state.tasks),
          tasks: state.tasks.map(t => t.id === id ? { ...t, quadrant } : t),
        }));
      },

      moveTasks: (ids, quadrant) => {
        const idSet = new Set(ids);
        set(state => ({
          ...pushHistory(state as TaskStore, state.tasks),
          tasks: state.tasks.map(t => idSet.has(t.id) ? { ...t, quadrant } : t),
          selectedIds: new Set(),
        }));
      },

      reorderTasks: (quadrant, activeId, overId) => {
        set(state => {
          const quadrantTasks = state.tasks.filter(t => t.quadrant === quadrant && !t.isArchived);
          const otherTasks = state.tasks.filter(t => !(t.quadrant === quadrant && !t.isArchived));

          const activeIndex = quadrantTasks.findIndex(t => t.id === activeId);
          const overIndex = quadrantTasks.findIndex(t => t.id === overId);

          if (activeIndex === -1 || overIndex === -1) return {};

          const reordered = [...quadrantTasks];
          const [moved] = reordered.splice(activeIndex, 1);
          reordered.splice(overIndex, 0, moved);

          return {
            ...pushHistory(state as TaskStore, state.tasks),
            tasks: [...otherTasks, ...reordered],
          };
        });
      },

      selectTask: (id, mode = 'single') => {
        set(state => {
          if (mode === 'toggle') {
            const next = new Set(state.selectedIds);
            if (next.has(id)) next.delete(id);
            else next.add(id);
            return { selectedIds: next };
          }
          if (mode === 'range') {
            // Select from focused to id
            const activeTasks = state.tasks.filter(t => !t.isArchived);
            const focusedIdx = activeTasks.findIndex(t => t.id === state.focusedId);
            const targetIdx = activeTasks.findIndex(t => t.id === id);
            if (focusedIdx === -1) return { selectedIds: new Set([id]) };
            const min = Math.min(focusedIdx, targetIdx);
            const max = Math.max(focusedIdx, targetIdx);
            const rangeIds = activeTasks.slice(min, max + 1).map(t => t.id);
            return { selectedIds: new Set(rangeIds) };
          }
          return { selectedIds: new Set([id]) };
        });
      },

      clearSelection: () => set({ selectedIds: new Set() }),
      setFocused: (id) => set({ focusedId: id }),

      setViewMode: (mode) => set({ viewMode: mode }),
      setFilter: (filter) => set(state => ({ filter: { ...state.filter, ...filter } })),
      setDarkMode: (mode) => set({ darkMode: mode }),
      setEditingId: (id) => set({ editingId: id }),

      undo: () => {
        set(state => {
          if (state.historyIndex < 0 || state.history.length === 0) return {};
          const prevIndex = state.historyIndex - 1;
          const prevState = prevIndex >= 0 ? state.history[prevIndex] : state.history[0];
          if (!prevState) return {};
          return {
            tasks: prevState.tasks,
            historyIndex: Math.max(0, prevIndex),
          };
        });
      },

      getTasksByQuadrant: (quadrant) => {
        return get().tasks.filter(t => t.quadrant === quadrant && !t.isArchived);
      },

      getArchivedTasks: () => {
        return get().tasks.filter(t => t.isArchived);
      },

      getFilteredTasks: (tasks) => {
        const { filter } = get();
        return tasks.filter(t => {
          if (filter.search) {
            const lower = filter.search.toLowerCase();
            if (!t.title.toLowerCase().includes(lower)) return false;
          }
          if (filter.quadrants.length > 0 && !filter.quadrants.includes(t.quadrant)) return false;
          if (filter.tags.length > 0 && !filter.tags.some(tag => t.tags.includes(tag))) return false;
          return true;
        });
      },

      getAllTags: () => {
        const tags = new Set<string>();
        get().tasks.forEach(t => t.tags.forEach(tag => tags.add(tag)));
        return [...tags].sort();
      },
    }),
    {
      name: 'bzpad-tasks',
      // Serialize Set as array
      storage: {
        getItem: (name) => {
          const str = localStorage.getItem(name);
          if (!str) return null;
          const parsed = JSON.parse(str);
          if (parsed.state?.selectedIds) {
            parsed.state.selectedIds = new Set(parsed.state.selectedIds);
          }
          return parsed;
        },
        setItem: (name, value) => {
          const toStore = {
            ...value,
            state: {
              ...value.state,
              selectedIds: [...(value.state.selectedIds || [])],
            },
          };
          localStorage.setItem(name, JSON.stringify(toStore));
        },
        removeItem: (name) => localStorage.removeItem(name),
      },
    }
  )
);
