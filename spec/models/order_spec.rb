require 'spec_helper'

describe Order do
  let(:order) { create(:order) }
  let(:product) { create(:product, cost_in_cents: 100000) }

  describe 'total cost in cents' do
    it 'is the sum of all the products on the order' do
      product2 = create(:product, cost_in_cents: 50000)
      order.products << product << product2
      expect(order.total_cost_in_cents).to eq (product2.cost_in_cents + product.cost_in_cents)
    end
  end

  describe 'new orders' do
    it 'starts off in the unsubmitted state' do
      order = create(:order)

      expect(order.unsubmitted?).to eq true
    end
  end

  describe 'submitting' do
    context 'with products' do
      it 'transitions to the processing state' do
        order.products << product
        order.submit!
        expect(order.processing?).to eq true
      end
    end

    context 'without products' do
      it 'doesnt transition to processing' do
        expect {
          order.submit!
        }.to raise_error(AASM::InvalidTransition)
      end
    end
  end

  describe 'shipping an order' do
    it 'transitions to the shipped state' do
      order = create(:order, aasm_state: 'processing')
      order.ship!
      expect(order.shipped?).to eq true
    end
  end

  describe "adding a product" do
    context 'to an unsubmitted order' do
      context 'with remaining stock' do
        let(:product) { create(:product, amount_in_stock: 5) }

        it 'increases the total cost of the order' do
          expect {
            order.products << product
          }.to change { order.total_cost_in_cents }.by(product.cost_in_cents)
        end

        it 'adds the product to the order' do
          order.products << product
          expect(order.products).to include product
        end

        it 'decrements the amount of product in stock' do
          expect {
            order.products << product
          }.to change { product.amount_in_stock }.by(-1)
        end
      end

      context 'with no remaining stock' do
        let(:product) { create(:product, amount_in_stock: 0) }

        before do
          expect { product.orders << order }.to raise_error(ActiveRecord::RecordInvalid)
        end

        it 'does not add the product to the order' do
          expect(order.products).to_not include product
        end

        it 'does not decrement the amount of product in stock' do
          product.reload
          expect(product.amount_in_stock).to eq 0
        end
      end
    end

    context 'to a submitted order' do
      let(:order) do
        order = create(:order)
        order.products << create(:product)
        order.submit!
        order
      end

      let(:product) { create(:product, amount_in_stock: 5) }

      it 'raises an exception' do
        expect { order.products << product }.to raise_error(Order::InvalidState)
      end
    end
  end

  describe 'removing a product' do
    context 'from an unsubmitted order' do
      let(:product) { create(:product, amount_in_stock: 0) }

      it 'increases the amount of product left' do
        expect {
          order.products.destroy(product)
        }.to change { product.amount_in_stock }.by(1)
      end

      it 'remove the product from the relationship' do
        order.products.destroy(product)
        expect(order.products).to_not include(product)
      end
    end

    context 'from a submitted order' do
      let(:order) do
        order = create(:order)
        order.products << create(:product)
        order.submit!
        order
      end

      it 'raises an exception' do
        product = order.products.first
        expect { order.products.destroy(product) }.to raise_error(Order::InvalidState)
      end
    end
  end
end
