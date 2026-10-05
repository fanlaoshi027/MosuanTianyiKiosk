$ErrorActionPreference = 'Stop'

# Stable build mode.
# The previous implementation modified PlayerPage.xaml and PlayerPage.xaml.cs.
# That injected a second Grid.Children collection and caused WMC0035 during
# XAML compilation. Keep this patch intentionally inert until the crop/mask
# controls are implemented outside PlayerPage's root visual tree.

Write-Host 'Mosuan player feature patch: stable no-op.'