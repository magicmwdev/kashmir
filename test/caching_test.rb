require 'ar_test_helper'

describe 'Caching' do

  before(:all) do
    TestData.create_tom
    @restaurant = AR::Restaurant.find_by_name('Chef Tom Belly Burgers')
  end

  before(:each) do
    Kashmir::Caching.flush!
  end

  def from_cache(definition, model)
    Kashmir::Caching.from_cache(definition, model)
  end

  describe 'flat data' do
    it 'loads the same exact data from cache' do
      representation = @restaurant.represent([:name])
      @restaurant.reload
      cached_representation = @restaurant.represent([:name])
      assert_equal representation, cached_representation
    end

    it 'stores the data in cache' do
      representation = @restaurant.represent([:name])
      cached_representation = from_cache([:name], @restaurant)
      assert_equal representation, cached_representation
    end
  end

  describe 'references to other representations' do
    it 'does not perform the same query twice' do
      selects = track_queries do
        @restaurant.represent([:name, :owner])
      end
      assert_equal 1, selects.size

      # clear active record cache for this instance
      @restaurant.reload
      selects = track_queries do
        @restaurant.represent([:name, :owner])
      end
      assert_equal 0, selects.size
    end

    it 'loads the same exact data from cache' do
      representation = @restaurant.represent([:name, :owner])
      @restaurant.reload
      cached_representation = @restaurant.represent([:name, :owner])
      assert_equal representation, cached_representation
    end

    it 'stores the data in cache at every level' do
      representation = @restaurant.represent([:name, owner: [:name] ])
      cached_restaurant_with_chef = from_cache([:name, owner: [ :name ]], @restaurant)

      assert_equal representation, cached_restaurant_with_chef

      chef = @restaurant.owner
      cached_chef = from_cache([:name], chef)

      assert_equal cached_chef, representation[:owner]
    end
  end

  describe 'nesting' do
    before(:all) do
      @chef = @restaurant.owner
      @chef.reload
    end

    it 'caches at every level' do
      representation = @chef.represent([:name, :restaurant =>[ :name, :rating =>[ :value ]]])
      fully_cached_chef = from_cache([:name, :restaurant =>[ :name, :rating =>[ :value ]]], @chef)
      assert_equal representation, fully_cached_chef

      fully_cached_restaurant = from_cache([ :name, :rating => [:value] ], @restaurant)
      assert_equal representation[:restaurant], fully_cached_restaurant

      cached_rating = from_cache([:value], @restaurant.rating)
      assert_equal representation[:restaurant][:rating], cached_rating

      assert_equal 3, all_keys.size
    end

    it 'tries to hit the cache at every level' do
      selects = track_queries do
        representation = @chef.represent([:name, :restaurant =>[ :name, :rating =>[ :value ]]])
      end
      #  SELECT  "restaurants".* FROM "restaurants" WHERE "restaurants"."owner_id" = ? LIMIT 1
      #  SELECT  "ratings".* FROM "ratings" WHERE "ratings"."restaurant_id" = ? LIMIT 1
      assert_equal selects.size, 2

      @chef.reload
      selects = track_queries do
        representation = @chef.represent([:name, :restaurant =>[ :name, :rating =>[ :value ]]])
      end
      assert_equal selects.size, 0
    end

    it 'tries to fill holes in the cache graph' do
      definition = [:name, :restaurant =>[ :name, :rating =>[ :value ]]]
      representation = @chef.represent(definition)
      Kashmir::Caching.clear(definition, @chef)

      assert_equal 2, all_keys.size

      @chef.reload
      selects = track_queries do
        @chef.represent(definition)
      end
      # ratings is still cached
      # SELECT  "restaurants".* FROM "restaurants" WHERE "restaurants"."owner_id" = ? LIMIT 1
      assert_equal selects.size, 1
    end
  end

  describe 'collections' do
    it 'caches every item' do
      presented_recipes = AR::Recipe.all.represent([:title])

      cached_keys = %w(
        kashmir:AR::Recipe:1:[:title]
        kashmir:AR::Recipe:2:[:title]
      )

      assert_equal cached_keys.sort, all_keys.sort
    end

    it 'presents from cache' do
      selects = track_queries do
        AR::Recipe.all.represent([:title, :ingredients => [:name]])
      end
      # SELECT "recipes_ingredients".* FROM "recipes_ingredients" WHERE "recipes_ingredients"."recipe_id" IN (1, 2)
      # SELECT "ingredients".* FROM "ingredients" WHERE "ingredients"."id" IN (1, 2, 3, 4)
      assert_equal 3, selects.size

      selects = track_queries do
        AR::Recipe.all.represent([:title, :ingredients => [:name]])
      end
      # SELECT "recipes".* FROM "recipes"
      assert_equal 1, selects.size

      cache_keys = [
        "kashmir:AR::Ingredient:1:[:name]",
        "kashmir:AR::Ingredient:2:[:name]",
        "kashmir:AR::Recipe:1:[:title, {:ingredients=>[:name]}]",
        "kashmir:AR::Ingredient:3:[:name]",
        "kashmir:AR::Ingredient:4:[:name]",
        "kashmir:AR::Recipe:2:[:title, {:ingredients=>[:name]}]"
      ]

      assert_equal cache_keys.sort, all_keys.sort
    end
  end
end