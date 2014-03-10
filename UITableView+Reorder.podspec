Pod::Spec.new do |s|
  s.name = "UITableView+Reorder"
  s.version = "1.0.2"
  s.summary = "Easy Row Reordering for UITableView without Edit Mode"
  s.homepage = "https://github.com/LavaSlider/UITableView-Reorder"
  s.license = 'MIT'
  s.author = { "David W. Stockton" => "stockton@syntonicity.net" }
  s.source = { :git => "https://github.com/LavaSlider/UITableView-Reorder.git", :tag => "1.0.2" }
  s.platform = :ios, '5.0'
  s.source_files = 'UITableView+Reorder/**/*.{h,m}'
  s.frameworks = 'UIKit', 'CoreGraphics', 'QuartzCore'
  s.requires_arc = true
end