#!/usr/bin/env ruby
# 
# sync-project.rb
# 
# Syncs the Xcode project file with the filesystem.
# Adds any new .swift files that exist on disk but not in the project.
#
# Usage: ./scripts/sync-project.rb
#
# Note: This only ADDS files. It does not remove stale references to avoid
# breaking the project structure. Use Xcode to manually remove deleted files.
#

require 'xcodeproj'

PROJECT_PATH = File.join(__dir__, '..', 'Antigravity Stats Menu.xcodeproj')
ROOT_PATH = File.expand_path(File.join(__dir__, '..'))
SOURCE_DIR = 'Antigravity Stats Menu'
TEST_DIR = 'Antigravity Stats MenuTests'

def sync_project
  project = Xcodeproj::Project.open(PROJECT_PATH)
  
  added_count = 0
  
  # Sync main source directory
  added_count += sync_directory(project, SOURCE_DIR, ['Antigravity Stats Menu'])
  
  # Sync test directory
  added_count += sync_directory(project, TEST_DIR, ['Antigravity Stats MenuTests'])
  
  if added_count > 0
    project.save
    puts "✅ Added #{added_count} new file(s) to project"
  else
    puts "✅ Project is in sync with filesystem"
  end
end

def sync_directory(project, dir_path, target_names)
  full_path = File.join(ROOT_PATH, dir_path)
  return 0 unless File.directory?(full_path)
  
  added = 0
  targets = target_names.map { |name| project.targets.find { |t| t.name == name } }.compact
  
  # Find all .swift files on disk
  swift_files = Dir.glob(File.join(full_path, '**', '*.swift'))
  
  swift_files.each do |file_path|
    # Check if file is already in project
    existing = project.files.find { |f| f.real_path&.to_s == file_path }
    next if existing
    
    # Get path relative to project root
    relative_path = file_path.sub(ROOT_PATH + '/', '')
    
    # Find or create the group for this file
    group = find_or_create_group(project, File.dirname(relative_path))
    
    # Add file reference
    file_ref = group.new_file(File.basename(file_path))
    
    # Add to build phases of specified targets
    targets.each do |target|
      target.source_build_phase.add_file_reference(file_ref)
    end
    
    puts "  + #{relative_path}"
    added += 1
  end
  
  added
end

def find_or_create_group(project, path)
  components = path.split('/')
  current_group = project.main_group
  
  components.each do |component|
    next if component.empty?
    child = current_group.children.find { |c| c.display_name == component }
    if child && child.is_a?(Xcodeproj::Project::Object::PBXGroup)
      current_group = child
    else
      current_group = current_group.new_group(component, component)
    end
  end
  
  current_group
end

sync_project
