import { mutation } from "./_generated/server";

export const seedTasks = mutation({
  args: {},
  handler: async (ctx) => {
    const existing = await ctx.db.query("tasks").first();
    if (existing) {
      return { seeded: false, message: "Tasks already exist, skipping seed." };
    }

    const tasks = [
      { title: "Deploy Convex backend", completed: false },
      { title: "Set environment variables", completed: false },
      { title: "Run smoke test", completed: false },
    ];

    const now = Date.now();
    for (const task of tasks) {
      await ctx.db.insert("tasks", { ...task, createdAt: now });
    }

    return { seeded: true, message: `Seeded ${tasks.length} tasks.` };
  },
});
