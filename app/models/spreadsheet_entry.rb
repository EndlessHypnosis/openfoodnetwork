# Class for defining spreadsheet entry objects for use in ProductImporter
class SpreadsheetEntry
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations

  attr_reader :validates_as

  attr_accessor :line_number, :valid, :product_object, :product_validations, :on_hand_nil,
                :has_overrides, :units, :unscaled_units, :unit_type, :tax_category, :shipping_category

  attr_accessor :id, :product_id, :producer, :producer_id, :supplier, :supplier_id, :name, :display_name, :sku,
                :unit_value, :unit_description, :variant_unit, :variant_unit_scale, :variant_unit_name,
                :display_as, :category, :primary_taxon_id, :price, :on_hand, :count_on_hand, :on_demand,
                :tax_category_id, :shipping_category_id, :description, :import_date

  def initialize(attrs)
    #@product_validations = {}
    @validates_as = ''

    #validate_custom_unit_fields(attrs, is_inventory)
    convert_custom_unit_fields(attrs)

    attrs.each do |k, v|
      if self.respond_to?("#{k}=")
        send("#{k}=", v) unless non_product_attributes.include?(k)
      else
        # Trying to assign unknown attribute... record this and give feedback or
        # just continue to ignore silently?
      end
    end
  end

  def unit_scales
    {
      'g' => {scale: 1, unit: 'weight'},
      'kg' => {scale: 1000, unit: 'weight'},
      't' => {scale: 1000000, unit: 'weight'},
      'ml' => {scale: 0.001, unit: 'volume'},
      'l' => {scale: 1, unit: 'volume'},
      'kl' => {scale: 1000, unit: 'volume'}
    }
  end

  def convert_custom_unit_fields(attrs)
    # unit unit_type variant_unit_name   ->    unit_value  variant_unit_scale   variant_unit
    # 250    ml       nil      ....              0.25        0.001               volume
    # 50     g        nil      ....              50          1                   weight
    # 2     kg        nil      ....              2000        1000                weight
    # 1     nil       bunches  ....              1           null                items

    attrs['variant_unit'] = nil
    attrs['variant_unit_scale'] = nil
    attrs['unit_value'] = nil

    if attrs.key?('units') && attrs['units'].present?
      attrs['unscaled_units'] = attrs['units']
    end

    if attrs.key?('units') && attrs.key?('unit_type') && attrs['units'].present? && attrs['unit_type'].present?
      units = attrs['units'].to_f
      unit_type = attrs['unit_type'].to_s.downcase

      if valid_unit_type? unit_type
        attrs['variant_unit'] = unit_scales[unit_type][:unit]
        attrs['variant_unit_scale'] = unit_scales[unit_type][:scale]
        attrs['unit_value'] = (units || 0) * attrs['variant_unit_scale']
      end
    end

    return unless attrs.key?('units') && attrs.key?('variant_unit_name') && attrs['units'].present? && attrs['variant_unit_name'].present?

    attrs['variant_unit'] = 'items'
    attrs['variant_unit_scale'] = nil
    attrs['unit_value'] = units || 1
  end

  def persisted?
    false #ActiveModel
  end

  def is_a_valid?(type)
    #@validates_as[type]
    @validates_as == type
  end

  def is_a_valid(type)
    #@validates_as.push type
    @validates_as = type
  end

  def has_errors?
    self.errors.count > 0 or @product_validations
  end

  def attributes
    attrs = {}
    self.instance_variables.each do |var|
      attrs[var.to_s.delete("@")] = self.instance_variable_get(var)
    end
    attrs.except(*non_product_attributes)
  end

  def displayable_attributes
    # Modified attributes list for displaying in user feedback
    attrs = {}
    self.instance_variables.each do |var|
      attrs[var.to_s.delete("@")] = self.instance_variable_get(var)
    end
    attrs.except(*non_product_attributes, *non_display_attributes)
  end

  def invalid_attributes
    invalid_attrs = {}
    errors = @product_validations ? self.errors.messages.merge(@product_validations.messages) : self.errors.messages
    errors.each do |attr, message|
      invalid_attrs[attr.to_s] = "#{attr.to_s.capitalize} #{message.first}"
    end
    invalid_attrs.except(*non_product_attributes, *non_display_attributes)
  end

  private

  def valid_unit_type?(unit_type)
    unit_scales.key? unit_type
  end

  def non_display_attributes
    ['id', 'product_id', 'unscaled_units', 'variant_id', 'supplier_id', 'primary_taxon', 'primary_taxon_id', 'category_id', 'shipping_category_id', 'tax_category_id', 'variant_unit_scale', 'variant_unit', 'unit_value']
  end

  def non_product_attributes
    ['line_number', 'valid', 'errors', 'product_object', 'product_validations', 'inventory_validations', 'validates_as', 'save_type', 'on_hand_nil', 'has_overrides', 'tax_category', 'shipping_category']
  end
end
