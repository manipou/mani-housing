local Config = {}

Config.Debug = true -- TODO: Remove Debug when on live server

Config.WhitelistedJobs = {
	'realestate'
}

Config.Commands = {
    ['RealEstate'] = 'housing',
	['HouseInteraction'] = 'house'
}

Config.Distances = {
	['Main'] = 7.5, -- When the player can use house interactions.
	['Garage'] = 2.5, -- When the player can enter and interact with the garage.
	['Interact'] = 0.75, -- When the player can enter and interact with interactions.
	['JobMode'] = 20.0 -- Distance for real estate job mode.
}

Config.Commision = {
	['RealEstate'] = 0.10,
	['Agent'] = 0.02, -- Comment out, if Seller shoulnd't receive commision
	['Owner'] = 1.0
}

Config.StashPinEditCost = 10000

-- 'rcore_clothing' | 'illenium-appearance' | 'custom' (fill in your own logic in open/cl_open.lua)
Config.Clothing = 'rcore_clothing'

Config.Blips = {
	['Owned'] = {
		Sprite = 40,
		Color = 2,
		Scale = 0.8,
		Name = 'Owned Property'
	},
	['Keyholder'] = {
		Sprite = 40,
		Color = 3,
		Scale = 0.8,
		Name = 'Keyholder Property'
	},
	['ForSale'] = {
		Sprite = 374,
		Color = 1,
		Scale = 0.8,
		Name = 'Property For Sale'
	},
	['JobMode'] = {
		Sprite = 40,
		Color = 11,
		Scale = 0.8,
		Name = 'Registered Property'
	}
}

Config.ZOffset = 1000 -- How high the player should be when they enter the house. (Set to -Number if you want to lower the player)

Config.Shells = {
    {
		Model = 'shell_garagem',
        Label = 'Medium Garage',
		Stash = {
			Weight = 1000000,
			Slots = 100
		},
		Offsets = {
			Exit = vec4(13.64, 1.71, -1.25, 89.74)
		}
	},
    {
		Model = 'shell_trailer',
        Label = 'Trailer',
		Stash = {
			Weight = 1000000,
			Slots = 100
		},
		Offsets = {
			Exit = vec4(-1.37, -1.99, -0.98, 357.81)
		}
	},
    {
		Model = 'shell_warehouse1',
        Label = 'Warehouse',
		Stash = {
			Weight = 1000000,
			Slots = 100
		},
		Offsets = {
			Exit = vec4(-8.86, 0.08, -1.45, 268.35)
		}
	},
    {
		Model = 'standardmotel_shell',
        Label = 'Standard Motel',
		Stash = {
			Weight = 1000000,
			Slots = 100
		},
		Offsets = {
			Exit = vec4(-0.47, -2.47, -1.06, 270.45)
		}
	},
    {
		Model = 'container_shell',
        Label = 'Container',
		Stash = {
			Weight = 1000000,
			Slots = 100
		},
		Offsets = {
			Exit = vec4(-0.01, -5.58, -0.71, 0.44)
		}
	},
    {
		Model = 'shell_store1',
        Label = 'Store',
		Stash = {
			Weight = 1000000,
			Slots = 100
		},
		Offsets = {
			Exit = vec4(-2.75, 4.53, -1.12, 181.69)
		}
	},
    {
		Model = 'furnitured_midapart',
        Label = 'Mid Apartment',
		Stash = {
			Weight = 1000000,
			Slots = 100
		},
		Offsets = {
			Exit = vec4(1.46, -10.25, -1.02, 0.88)
		}
	},
}

Config.FreeFurnitue = true

Config.Furniture = {
    ['Art'] = {
        {
            Model = 'apa_p_h_acc_artwalls_04',
            Label = 'Framed Jersey A',
            Price = 100,
        },
        {
            Model = 'apa_p_h_acc_artwalls_03',
            Label = 'Framed Jersey B',
            Price = 100,
        },
    },
    ['Walls'] = {
        {
            Model = 'prop_ld_fragwall_01a',
            Label = 'Fragmented Wall A',
            Price = 100,
        },
        {
            Model = 'prop_ld_fragwall_01b',
            Label = 'Fragmented Wall B',
            Price = 100,
        },
    }
}

return Config