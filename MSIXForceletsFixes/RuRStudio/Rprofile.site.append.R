
# --- MSIX package RuRStudio (Fix-RuRStudio.ps1) ---
# The R library in the package (R_HOME\library) is read-only. Use R's default personal library R_LIBS_USER
# (%LOCALAPPDATA%\R\win-library\<x.y>); R only uses it when the folder exists, so create it here.
# Works for every R process of the package (RStudio rsession, Rgui, Rterm, Rscript); no ILV, no PSF.
local({
  d <- Sys.getenv("R_LIBS_USER")
  if (nzchar(d) && !dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  if (dir.exists(d)) .libPaths(c(d, .libPaths()))
})
