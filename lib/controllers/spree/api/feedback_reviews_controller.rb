# frozen_string_literal: true

module Spree
  module Api
    class FeedbackReviewsController < Spree::Api::BaseController
      respond_to :json

      before_action :load_review, only: [:create, :update, :destroy]
      before_action :load_product, :find_review_user
      before_action :sanitize_rating, only: [:create, :update]
      before_action :prevent_multiple_reviews, only: [:create]

      def create
        return not_found if @product.nil?

        if @review.present?
          @feedback_review = @review.feedback_reviews.new(feedback_review_params)
          @feedback_review.user = @current_api_user
          @feedback_review.locale = I18n.locale.to_s if Spree::Reviews::Config[:track_locale]
        end

        authorize! :create, @feedback_review
        if @review.save
          render json: @feedback_review
        else
          invalid_resource!(@feedback_review)
        end
      end

      def update
        authorize! :update, @review

        attributes = review_params.merge(ip_address: request.remote_ip, approved: false)

        if @review.update(attributes)
          render json: @review, include: [:images, :feedback_reviews], status: :ok
        else
          invalid_resource!(@review)
        end
      end

      def destroy
        authorize! :destroy, @review

        if @review.destroy
          render json: @review, status: :ok
        else
          invalid_resource!(@review)
        end
      end

      private

      def permitted_feedback_review_attributes
        [:rating, :comment]
      end

      def feedback_review_params
        params.require(:feedback_review).permit(permitted_feedback_review_attributes)
      end

      # Loads product from product id.
      def load_product
        @product = if params[:product_id]
                     Spree::Product.friendly.find(params[:product_id])
                   else
                     @review&.product
                   end
      end

      # Finds user based on api_key or by user_id if api_key belongs to an admin.
      def find_review_user
        if params[:user_id] && @current_user_roles.include?('admin')
          @current_api_user = Spree.user_class.find(params[:user_id])
        end
      end

      # Loads any review that is shared between the user and product
      def load_review
        @review = Spree::Review.find(params[:id_review])
      end

      def load_feedback_review
        
      end

      # Ensures that a user can't create more than 1 review per product
      def prevent_multiple_reviews
        @review = @current_api_user.reviews.find_by(product: @product)
        if @review.present?
          invalid_resource!(@review)
        end
      end

      # Converts rating strings like "5 units" to "5"
      # Operates on params
      def sanitize_rating
        params[:rating].sub!(/\s*[^0-9]*\z/, '') if params[:rating].present?
      end
    end
  end
end