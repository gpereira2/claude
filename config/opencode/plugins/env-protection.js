export const EnvProtection = async ({ project, client, $, directory, worktree }) => {
  const isProtectedEnv = (filePath) => {
    if (!filePath) return false
    if (/\.env\.example$/.test(filePath)) return false
    return /(^|\/)\.env($|\.)/.test(filePath)
  }

  return {
    "tool.execute.before": async (input, output) => {
      const tool = input.tool

      // Block read/edit/write of .env files (except .env.example)
      if (["read", "edit", "write"].includes(tool)) {
        const filePath = output.args.filePath || output.args.path || ""
        if (isProtectedEnv(filePath)) {
          throw new Error("Access to .env files is blocked to protect secrets.")
        }
      }

      // Block bash commands that reference .env files (except .env.example)
      if (tool === "bash") {
        const cmd = output.args.command || ""
        if (/(^|\/)\.env($|\.)/.test(cmd) && !/\.env\.example/.test(cmd)) {
          throw new Error("Bash access to .env files is blocked to protect secrets.")
        }
      }
    },
  }
}
