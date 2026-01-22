#!/usr/bin/env ruby
# Add new AI feature Swift files to URL-Analysis Xcode project

require 'xcodeproj'

project_path = 'URL-Analysis.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'URL Analysis' }
main_group = project.main_group.groups.find { |g| g.display_name == 'URL-Analysis' }

unless target && main_group
  puts "Error: Could not find target or group"
  exit 1
end

new_files = [
  'CodeGenerationView.swift',
  'TimeMachineView.swift',
  'AITrendAnalysisView.swift',
  'RegressionDetectionView.swift'
]

puts "Adding #{new_files.count} new AI feature files..."

new_files.each do |file_name|
  file_path = File.join('URL-Analysis', file_name)
  unless File.exist?(file_path)
    puts "  ❌ File not found: #{file_path}"
    next
  end

  # Remove old reference if exists
  main_group.files.to_a.each do |file_ref|
    if file_ref.display_name == file_name
      file_ref.remove_from_project
    end
  end

  # Add new reference
  file_ref = main_group.new_reference(file_name)
  file_ref.source_tree = '<group>'
  target.source_build_phase.add_file_reference(file_ref)

  puts "  ✅ Added #{file_name}"
end

project.save

puts "\n✅ Successfully added all AI feature files to Xcode project"
