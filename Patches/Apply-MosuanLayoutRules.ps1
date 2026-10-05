$ErrorActionPreference = 'Stop'

# Stable core-build mode.
# Do not modify PlayerPage.xaml or PlayerPage.xaml.cs here.
# The previous implementation injected fields/methods into the upstream
# PlayerPage code and produced CS0106/CS1529 during XAML precompile.
# Crop/mask normalized-coordinate support will be implemented as a separate
# UI/service layer after the unmodified core package builds successfully.

Write-Host 'Mosuan normalized layout patch: stable no-op.'