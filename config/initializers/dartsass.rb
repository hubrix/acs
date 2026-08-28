# Replaces the Compass build (config.rb) that produced
# public/stylesheets/compiled/*.css. Output lands in app/assets/builds and is
# served, digested, by Propshaft.
#
# _tokens.scss is a partial: it holds only variables and is pulled in by the
# others through @use, so it is not built on its own.
Rails.application.config.dartsass.builds = {
  'style.scss' => 'style.css',
  'css3buttons.scss' => 'css3buttons.css',
  'common.scss' => 'common.css',
  'styles.scss' => 'styles.css'
}
