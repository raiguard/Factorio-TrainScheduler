local table = require("__flib__.table")
local train_util = require("__flib__.train")

local global_data = {}

function global_data.init()
  global.flags = {
    trains_need_removing = false
  }
  -- TODO: generate tables for each force
  global.groups = {
    [1] = {
      ["TESTGROUP"] = {
        name = "TESTGROUP",
        colors = {},
        schedule = nil,
        trains = {}
      },
      ["TESTGROUP2"] = {
        name = "TESTGROUP2",
        colors = {},
        schedule = nil,
        trains = {}
      }
    }
  }
  global.opened_locomotives = {}
  global.players = {}
  global.trains = {}
  global.trains_to_remove = {}
end

function global_data.add_train(train, group)
  local train_id = train.id
  game.print("ADD TRAIN: ["..train.id.."]")

  global.trains[train_id] = {
    force_index = train_util.get_main_locomotive(train).force.index,
    id = train_id,
    train = train
  }

  global_data.change_train_group(global.trains[train_id], group)
end

function global_data.remove_train(train_data)
  game.print("REMOVE TRAIN: ["..train_data.id.."]")
  global_data.change_train_group(train_data)
  global.trains[train_data.id] = nil
end

-- TODO: separate groups by force
function global_data.change_train_group(train_data, new_group)
  -- remove from old group
  local old_group = train_data.group
  game.print("CHANGE TRAIN GROUP: ["..train_data.id.."] | ["..(old_group or "").."] -> ["..(new_group or "").."]")
  if old_group then
    -- assume this will exist - if it doesn't, we have bigger problems!
    local group_data = global.groups[train_data.force_index][old_group]
    local group_trains = group_data.trains
    table.remove(group_trains, table.search(group_trains, train_data.id))
  end
  if new_group then
    -- add to new group
    train_data.group = new_group
    local group_data = global.groups[train_data.force_index][new_group]
    -- assume this is valid
    local group_trains = group_data.trains
    group_trains[#group_trains+1] = train_data.id
    if group_data.schedule then
      train_data.train.schedule = {
        current = 1,
        records = group_data.schedule
      }
    else
      train_data.train.schedule = nil
    end
  end
end

function global_data.migrate_trains(train, old_id_1, old_id_2)
  local locomotives = train.locomotives
  if #locomotives.front_movers == 0 and #locomotives.back_movers == 0 then
    -- remove the trains entirely
    for _, id in ipairs{old_id_1, old_id_2} do
      local train_data = global.trains[id]
      if train_data then
        global_data.remove_train(train_data)
      end
    end
  else
    game.print("MIGRATE TRAIN: ["..train.id.."] <- ["..(old_id_1 or "nil").."] ["..(old_id_2 or "nil").."]")
    local added = false
    local schedule = train.schedule
    for _, id in ipairs{old_id_1, old_id_2} do
      local train_data = global.trains[id]
      if train_data then
        local group_data = global.groups[train_data.force_index][train_data.group]
        if group_data and table.deep_compare(schedule.records, group_data.schedule) then
          if not added then
            added = true
            global_data.add_train(train, train_data.group)
          end
        end
        global.trains_to_remove[id] = true
        global.flags.trains_need_removing = true
        REGISTER_ON_TICK()
      end
    end
  end
end

function global_data.update_group_schedule(train)
  local train_data = global.trains[train.id]
  -- if the `updating_schedule` flag is active, then it is being updated as a part of another call to this function
  if train_data and not train_data.updating_schedule then
    local group_data = global.groups[train_data.force_index][train_data.group]
    if group_data then
      -- update stored schedule for the group
      local train_schedule = train.schedule
      group_data.schedule = train_schedule and train_schedule.records
      -- update schedule for all trains in the group
      for _, train_id in ipairs(group_data.trains) do
        if train_id ~= train.id then
          local other_train_data = global.trains[train_id]
          if other_train_data then
            local other_train = other_train_data.train
            local other_train_schedule = other_train.schedule
            other_train_data.updating_schedule = true
            if train_schedule then
              other_train.schedule = {
                current = other_train_schedule and other_train_schedule.current or 1,
                records = train_schedule.records
              }
            else
              other_train.schedule = nil
            end
            other_train_data.updating_schedule = nil
          end
        end
      end
    end
  end
end

return global_data