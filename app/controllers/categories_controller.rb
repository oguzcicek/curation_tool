class CategoriesController < ApplicationController
  before_action :set_category, only: [:show, :edit, :update, :destroy]

  def index
    @categories = Category.all.order(:name)
  end

  def show
    @mappings = @category.text_mappings.order(processed: :asc, processed_at: :desc, original_text: :asc)
    
    @processed_count = @mappings.where(processed: true).count
    @unprocessed_count = @mappings.where(processed: false).count
  end

  def new
    @category = Category.new
  end

  def create
    @category = Category.new(category_params)

    if @category.save
      redirect_to categories_path, notice: 'Category was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to categories_path, notice: 'Category was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @category.text_mappings.exists?
      redirect_to categories_path, alert: 'Cannot delete category that has text mappings. Reassign the mappings first.'
    else
      @category.destroy
      redirect_to categories_path, notice: 'Category was successfully deleted.'
    end
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :description)
  end
end
