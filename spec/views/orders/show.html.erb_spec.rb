require 'rails_helper'

RSpec.describe "orders/show", type: :view do
  before(:each) do
    @order = assign(:order, Order.create!(
      :step => "Step"
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Step/)
  end
end
