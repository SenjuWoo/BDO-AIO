# Obsidian & Gold — approved UI facelift

Keep the existing WPF layout and workflows; update the installed app in place.
No dependencies, archives, version copies, or game/config writes during deployment.

- Replace literal UI colors with semantic DynamicResource brushes.
- Dark charcoal/gold is the default; Night uses dimmer surfaces; Light uses warm paper.
- Sidebar theme selector previews immediately. Save settings persists `uiTheme`
  through the existing atomic, conflict-checked config writer. Reload discards
  preview along with other unsaved edits. Unknown theme values fall back to Dark.
- Theme all shared controls including popups, tooltips, validation messages and
  generated form controls. Preserve keyboard focus and native window resizing.
- Gold selected-page marker, framed overview card and clearer section hierarchy.

## Execution / verification

1. Add failing dashboard tests for defaults, live switching, Save/Reload,
   invalid-value fallback, resource coverage and popup foreground/background.
2. Implement shared brush palettes in `bdo_aio_gui.ps1`, resource references and
   restrained styling in `ui/dashboard.xaml`. No backend schema change needed:
   Save-Config already preserves extension properties.
3. Run dashboard suite; render all pages in all themes at 1120 and 940 widths.
   Inspect actual rendered output and repair clipping/contrast defects.
4. Run existing Python and PowerShell gates; commit source and synchronize only
   changed files to the installed app. Verify hashes and unchanged personal config.
