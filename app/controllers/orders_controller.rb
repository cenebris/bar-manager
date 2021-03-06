class OrdersController < ApplicationController
  before_action :set_order, only: [:show, :edit, :update, :destroy, :next_step]
  before_action :set_products, only: [:new, :edit, :update]

  def index
    @orders = Order.all
  end

  def new
    @order = Order.new(step: Order::STEPS.first)
    3.times { @order.order_items.build(quantity: 0) }
  end

  def edit
    3.times { @order.order_items.build(quantity: 0) }
  end

  def create
    @order = Order.new(order_params)
    @order.remove_invalid_order_items
    add_new_item_from_create if params[:add_new_item]
    transfer_to_kitchen_from_create if params[:transfer_to_kitchen]
    destroy if params[:delete_order]
  end

  def queued
    render_queue Order.queued
  end

  def in_progress
    render_queue Order.in_progress
  end

  def ready
    render_queue Order.ready
  end

  def released
    render_queue Order.released
  end

  def update
    @order.remove_invalid_order_items
    remove_zombie_order_items
    new_order_params = clean_order_params

    add_new_item_from_update(new_order_params) if params[:add_new_item]
    transfer_to_kitchen_from_update(new_order_params) if params[:transfer_to_kitchen]
    destroy if params[:delete_order]
  end

  def destroy
    @order.destroy
    redirect_to new_order_path if params[:action] == 'edit'
    redirect_to :back
  end

  def next_step
    current_index = Order::STEPS.index(@order.step)
    @order.step = Order::STEPS[current_index + 1]
    @order.save
    notify
    redirect_to :back
  end

  private
  def set_order
    @order = Order.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to new_order_path
  end

  def set_products
    @products = Product.cached_products
  end

  def order_params
    params.require(:order)
          .permit(:step,
                  order_items_attributes: [
                    :id,
                    :product_id,
                    :order_id,
                    :quantity,
                    :transfer_to_kitchen,
                    :add_new_item
                  ])
  end

  def remove_zombie_order_items
    atts = order_params['order_items_attributes']
    zombies = atts.select { |_, v| v['quantity'].to_i.zero? && !v['product_id'].blank? }
    if zombies
      zombies = zombies.map { |_, v| v[:id] }
      zombies.each { |z| OrderItem.find(z).delete }
    end
  end

  def clean_order_params
    new_order_params = order_params.dup
    new_order_params['order_items_attributes'].delete_if do |_, v|
      v['quantity'].to_i.zero? || v['product_id'].to_i.zero?
    end
    new_order_params
  end

  def transfer_to_kitchen_from_create
    @order.step = 'queued'
    @order.save
    notify
    redirect_to new_order_path
  end

  def add_new_item_from_create
    @order.save
    redirect_to edit_order_path(@order)
  end

  def transfer_to_kitchen_from_update(new_order_params)
    @order.step = 'queued'
    @order.update(new_order_params)
    notify
    redirect_to new_order_path
  end

  def add_new_item_from_update(new_order_params)
    @order.update(new_order_params)
    redirect_to edit_order_path(@order)
  end

  def render_queue(orders)
    @orders = orders
    render template: 'orders/queue'
  end

  def notify
    action = params[:action]
    new_order_notification if action == 'create' || params[:action] == 'update'
    order_in_progress_notification if action == 'next_step' && @order.next_step?('ready')
    order_ready_notification if action == 'next_step' && @order.next_step?('released')
  end

  def new_order_notification
    NotificationService.call "Order #{@order.id} sent to Kitchen", 15_000, 'red'
  end

  def order_in_progress_notification
    NotificationService.call "Order #{@order.id} in Progress", 5_000, 'orange'
  end

  def order_ready_notification
    NotificationService.call "Order #{@order.id} Ready", 10_000, 'green'
  end
end
