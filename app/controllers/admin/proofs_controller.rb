# encoding: UTF-8
# frozen_string_literal: true

module Admin
  class ProofsController < BaseController
    load_and_authorize_resource

    def index
      @grid = ProofsGrid.new(params[:proofs_grid])
      @assets = @grid.assets.includes(:currency).page(params[:page])
    end

    def edit
    end

    def update
      if @proof.update_attributes(proof_params)
        redirect_to action: :index
      else
        render :edit
      end
    end

    private

    def proof_params
      params.required(:proof).permit(:balance)
    end

  end
end
