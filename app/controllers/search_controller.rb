class SearchController < ApplicationController
  before_action :require_admin

  # Models that carried a Sphinx `define_index` block, now searched through
  # pg_search scopes instead of a Sphinx daemon. The view groups results by
  # class and renders admin/<table>/_table for each group.
  SEARCHABLE = [User, Job, Resource, ResourceGroup, Department, Location, Company].freeze

  RESULT_LIMIT = 50

  def index
    @query = params[:q].to_s.strip

    @results = if @query.blank?
                 []
               else
                 SEARCHABLE.flat_map { |model| model.full_text_search(@query).limit(RESULT_LIMIT).to_a }
               end

    @results_grouping = @results.group_by(&:class)
  end
end
