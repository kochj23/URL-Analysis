#!/usr/bin/env ruby
# Add new Swift files to URL-Analysis Xcode project

require 'xcodeproj'

project_path = 'URL-Analysis.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'URL Analysis' }

unless target
  puts "Error: Could not find 'URL Analysis' target"
  exit 1
end

# Get the URL-Analysis group
main_group = project.main_group.groups.find { |g| g.display_name == 'URL-Analysis' }

unless main_group
  puts "Error: Could not find 'URL-Analysis' group"
  exit 1
end

# New files to add (just filenames, they're in URL-Analysis directory)
new_files = [
  'ThemeManager.swift',
  'AdaptiveColors.swift',
  'DeviceEmulation.swift',
  'PersistentSession.swift',
  'SessionHistoryManager.swift',
  'HistoryView.swift',
  'TrendChartView.swift',
  'HeadlessAnalyzer.swift',
  'CLIOutputFormatter.swift',
  'LighthouseIntegration.swift',
  'LighthouseModels.swift',
  'LighthouseView.swift'
]

# First, remove any existing references to these files (from bad path)
puts "Cleaning up any existing bad references..."
target.source_build_phase.files.to_a.each do |build_file|
  if build_file.file_ref && new_files.include?(build_file.file_ref.display_name)
    puts "  🧹 Removing old reference: #{build_file.file_ref.display_name}"
    target.source_build_phase.remove_file_reference(build_file.file_ref)
  end
end

# Remove file references from group
main_group.files.to_a.each do |file_ref|
  if new_files.include?(file_ref.display_name)
    puts "  🧹 Removing old file reference: #{file_ref.display_name}"
    file_ref.remove_from_project
  end
end

# Save to apply removals
project.save

# Now add them with correct paths
puts "\nAdding #{new_files.count} new files to project..."

new_files.each do |file_name|
  # Check if file exists on disk
  file_path = File.join('URL-Analysis', file_name)
  unless File.exist?(file_path)
    puts "  ❌ File not found: #{file_path}"
    next
  end

  # Add file reference to group with relative path
  file_ref = main_group.new_reference(file_name)
  file_ref.source_tree = '<group>'

  # Add to target's source build phase
  target.source_build_phase.add_file_reference(file_ref)

  puts "  ✅ Added #{file_name}"
end

# Save project
project.save

puts "\n✅ Successfully added all new files to Xcode project"
puts "Next: Build the project with 'xcodebuild -scheme \"URL Analysis\" clean build'"
