class Order < ApplicationRecord
  has_many :order_items, inverse_of: :order, dependent: :destroy
  accepts_nested_attributes_for :order_items,
                                reject_if: lambda { |attributes| attributes['product_id'].blank? },
                                reject_if: lambda { |attributes| attributes['quantity'] == 0 }

  scope :queued, -> { where(step: 'queued') }
  scope :in_progress, -> { where(step: 'in_progress') }
  scope :ready, -> { where(step: 'ready') }
  scope :released, -> { where(step: 'released') }

  STEPS = %w(new queued in_progress ready released)

  def total_price
    order_items.reject { |x| x.id.nil? }
               .map { |item| item.product.price * item.quantity }.inject(:+)
  end

  def remove_invalid_order_items
    self.order_items = order_items.each do |x|
      x.delete if x.quantity.zero? || x.product_id.nil?
    end
  end

  def next_step?(x)
    x == Order::STEPS[Order::STEPS.index(step) + 1]
  end

end
