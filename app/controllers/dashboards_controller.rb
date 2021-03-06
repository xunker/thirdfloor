class DashboardsController < ApplicationController
  before_action :set_dashboard

  before_filter :login_required, except: :updates

  respond_to :html, :json

  # GET /dashboards
  def index
    @dashboards = Dashboard.all
  end

  # GET /dashboards/1
  def show
  end

  # GET /dashboards/new
  def new
    @dashboard = Dashboard.new
  end

  # GET /dashboards/1/edit
  def edit
    @dashboard.dashboard_cells.build
  end

  # POST /dashboards
  def create
    @dashboard = Dashboard.new(dashboard_params)

    if @dashboard.save
      redirect_to @dashboard, notice: 'Dashboard was successfully created.'
    else
      render action: 'new'
    end
  end

  # PATCH/PUT /dashboards/1
  def update
    if @dashboard.update(dashboard_params)
      redirect_to @dashboard, notice: 'Dashboard was successfully updated.'
    else
      render action: 'edit'
    end
  end

  def add_visualization
    visualization = Visualization.where(id: params[:visualization_id]).first!
    if visualization.disabled?
      render text: 'visualization not enabled', status: :unacceptable
    else
      if @dashboard.dashboard_cells.create(visualization: visualization, position: 99)
        @dashboard.reposition_cells
        render text: 'ok', status: :ok
      else
        render text: 'problem adding visualization', status: :unacceptable
      end
    end
  end

  def remove_visualization
    cell = @dashboard.dashboard_cells.where(id: params[:dashboard_cell_id]).first!
    cell.destroy if cell
    @dashboard.reposition_cells
    render text: 'ok', status: :ok
  end

  # DELETE /dashboards/1
  def destroy
    @dashboard.destroy
    redirect_to dashboards_url, notice: 'Dashboard was successfully destroyed.'
  end

  # Tells you the cells that need updating if the cell visualizations are
  # subscribed to a data point name (Visualization#data_point_name). Checks
  # to see if the last record created_at.to_i for that data point name is
  # greater than the 'since' query param. Array of the cell_ids that need to be
  # updated it returned along with a new "since" value that should be passed
  # next time.
  # Example: /dashboards/1/updates?since=1398721509
  def updates
    since = params.require(:since).to_i

    # default cache time is low because DataPoint.newest_for is cached longer.
    cache_time = (params[:cache_time] || 15.seconds).to_i

    json_response = Rails.cache.fetch(
      "dashboard_#{@dashboard.id}_updates_since_#{since}",
      expires_in: cache_time.seconds
    ) do
      cell_updates = []

      next_since = 0

      dps_cache = {} # don't load the same data twice, use this cache.

      @dashboard.dashboard_cells.each do |cell|
        if (data_point_name = cell.visualization.data_point_name).present?
          dp_since = (dps_cache[data_point_name] || (dps_cache[data_point_name] = DataPoint.newest_for(data_point_name).try(:created_at).to_i))
          next_since = dp_since if next_since < dp_since
          cell_updates << cell.id if since < dp_since
        end
      end

      # tell browser to update the whole dashboard if it's been changed.
      update_dashboard = false
      dash_updated = @dashboard.updated_at.to_i
      update_dashboard = true if dash_updated > since
      next_since = dash_updated if next_since < dash_updated

      {
        update: {
          cells: cell_updates,
          dashboard: update_dashboard
        },
        next_since: next_since
      }
    end

    respond_with(json_response) do |format|
      format.html { render text: json_response.to_json }
    end

  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_dashboard
      if (id = params[:id]).present?
        @dashboard = Dashboard.find(id)
      end
    end

    # Only allow a trusted parameter "white list" through.
    def dashboard_params
      params.require(:dashboard).permit(
        :name, :slug, :enabled, :refresh, :refresh_to, :css,
        :cell_width, :cell_height, :cell_x_margin, :cell_y_margin,
        :maximum_width, :maximum_height, :autoscroll, :autoscroll_delay,
        dashboard_cells_attributes: [ :id, :visualization_id, :dashboard_id, :autoscroll, :_destroy]
      )
    end
end
