-- ============================================================
-- QwikQ Database Schema for Supabase
-- ============================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- USERS TABLE
-- ============================================================
CREATE TABLE public.users (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  full_name TEXT NOT NULL,
  phone TEXT UNIQUE,
  email TEXT UNIQUE,
  avatar_url TEXT,
  role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin', 'super_admin')),
  points INTEGER DEFAULT 0,
  badges TEXT[] DEFAULT '{}',
  total_tokens_booked INTEGER DEFAULT 0,
  on_time_arrivals INTEGER DEFAULT 0,
  is_blocked BOOLEAN DEFAULT FALSE,
  fcm_token TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- SHOPS TABLE
-- ============================================================
CREATE TABLE public.shops (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  owner_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL CHECK (category IN ('canteen', 'hospital', 'bank', 'clinic', 'salon', 'pharmacy', 'government', 'other')),
  address TEXT,
  city TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  phone TEXT,
  logo_url TEXT,
  qr_code TEXT UNIQUE DEFAULT uuid_generate_v4()::TEXT,
  avg_service_time_minutes INTEGER DEFAULT 5,
  is_active BOOLEAN DEFAULT TRUE,
  is_open BOOLEAN DEFAULT FALSE,
  opening_time TIME DEFAULT '09:00',
  closing_time TIME DEFAULT '18:00',
  working_days INTEGER[] DEFAULT '{1,2,3,4,5}',
  max_tokens_per_day INTEGER DEFAULT 200,
  max_tokens_per_user INTEGER DEFAULT 3,
  allow_slot_booking BOOLEAN DEFAULT FALSE,
  slot_duration_minutes INTEGER DEFAULT 15,
  branch_id UUID REFERENCES public.shops(id),
  rating DECIMAL(2,1) DEFAULT 0.0,
  total_ratings INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TOKENS TABLE (Core)
-- ============================================================
CREATE TABLE public.tokens (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  token_number INTEGER NOT NULL,
  shop_id UUID REFERENCES public.shops(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  group_size INTEGER DEFAULT 1,
  status TEXT DEFAULT 'waiting' CHECK (status IN ('waiting', 'called', 'serving', 'completed', 'cancelled', 'expired', 'skipped')),
  is_priority BOOLEAN DEFAULT FALSE,
  priority_reason TEXT,
  booking_type TEXT DEFAULT 'token' CHECK (booking_type IN ('token', 'slot')),
  slot_start_time TIMESTAMPTZ,
  slot_end_time TIMESTAMPTZ,
  estimated_wait_minutes INTEGER,
  actual_wait_minutes INTEGER,
  ai_predicted_wait INTEGER,
  qr_code TEXT DEFAULT uuid_generate_v4()::TEXT,
  arrived_at TIMESTAMPTZ,
  served_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  cancel_reason TEXT,
  expiry_time TIMESTAMPTZ,
  notifications_sent TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- QUEUE TABLE (Live Queue State per Shop)
-- ============================================================
CREATE TABLE public.queues (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  shop_id UUID REFERENCES public.shops(id) ON DELETE CASCADE UNIQUE,
  current_token INTEGER DEFAULT 0,
  last_token_number INTEGER DEFAULT 0,
  total_waiting INTEGER DEFAULT 0,
  avg_service_time DECIMAL(5,2) DEFAULT 5.0,
  is_paused BOOLEAN DEFAULT FALSE,
  pause_reason TEXT,
  opened_at TIMESTAMPTZ,
  closed_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ANALYTICS TABLE
-- ============================================================
CREATE TABLE public.analytics (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  shop_id UUID REFERENCES public.shops(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  total_customers INTEGER DEFAULT 0,
  total_completed INTEGER DEFAULT 0,
  total_cancelled INTEGER DEFAULT 0,
  total_no_shows INTEGER DEFAULT 0,
  avg_wait_time DECIMAL(5,2) DEFAULT 0,
  avg_service_time DECIMAL(5,2) DEFAULT 0,
  peak_hour INTEGER,
  peak_count INTEGER DEFAULT 0,
  hourly_data JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(shop_id, date)
);

-- ============================================================
-- NOTIFICATIONS TABLE
-- ============================================================
CREATE TABLE public.notifications (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  token_id UUID REFERENCES public.tokens(id) ON DELETE CASCADE,
  shop_id UUID REFERENCES public.shops(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT CHECK (type IN ('turn_near', 'your_turn', 'missed', 'cancelled', 'priority', 'general')),
  is_read BOOLEAN DEFAULT FALSE,
  sent_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- REVIEWS TABLE
-- ============================================================
CREATE TABLE public.reviews (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  shop_id UUID REFERENCES public.shops(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  token_id UUID REFERENCES public.tokens(id),
  rating INTEGER CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(token_id, user_id)
);

-- ============================================================
-- SLOTS TABLE (for hybrid slot booking)
-- ============================================================
CREATE TABLE public.slots (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  shop_id UUID REFERENCES public.shops(id) ON DELETE CASCADE,
  slot_date DATE NOT NULL,
  slot_time TIME NOT NULL,
  capacity INTEGER DEFAULT 1,
  booked INTEGER DEFAULT 0,
  is_available BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(shop_id, slot_date, slot_time)
);

-- ============================================================
-- AI PREDICTION HISTORY (for training)
-- ============================================================
CREATE TABLE public.ai_predictions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  shop_id UUID REFERENCES public.shops(id) ON DELETE CASCADE,
  queue_length INTEGER,
  hour_of_day INTEGER,
  day_of_week INTEGER,
  avg_service_time DECIMAL(5,2),
  predicted_wait INTEGER,
  actual_wait INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES for performance
-- ============================================================
CREATE INDEX idx_tokens_shop_id ON public.tokens(shop_id);
CREATE INDEX idx_tokens_user_id ON public.tokens(user_id);
CREATE INDEX idx_tokens_status ON public.tokens(status);
CREATE INDEX idx_tokens_created_at ON public.tokens(created_at);
CREATE INDEX idx_shops_category ON public.shops(category);
CREATE INDEX idx_shops_location ON public.shops(latitude, longitude);
CREATE INDEX idx_analytics_shop_date ON public.analytics(shop_id, date);
CREATE INDEX idx_notifications_user ON public.notifications(user_id, is_read);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.queues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Users can view own profile" ON public.users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.users FOR INSERT WITH CHECK (auth.uid() = id);

-- Shops policies (public read)
CREATE POLICY "Anyone can view active shops" ON public.shops FOR SELECT USING (is_active = TRUE);
CREATE POLICY "Owners can manage their shops" ON public.shops FOR ALL USING (auth.uid() = owner_id);

-- Tokens policies
CREATE POLICY "Users can view own tokens" ON public.tokens FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create tokens" ON public.tokens FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can cancel own tokens" ON public.tokens FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Admins can view all tokens for their shop" ON public.tokens FOR SELECT 
  USING (shop_id IN (SELECT id FROM public.shops WHERE owner_id = auth.uid()));
CREATE POLICY "Admins can update tokens for their shop" ON public.tokens FOR UPDATE 
  USING (shop_id IN (SELECT id FROM public.shops WHERE owner_id = auth.uid()));

-- Queue policies
CREATE POLICY "Anyone can view queues" ON public.queues FOR SELECT USING (TRUE);
CREATE POLICY "Admins can manage queues" ON public.queues FOR ALL 
  USING (shop_id IN (SELECT id FROM public.shops WHERE owner_id = auth.uid()));

-- Notifications policies
CREATE POLICY "Users view own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);

-- ============================================================
-- REALTIME subscriptions
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.tokens;
ALTER PUBLICATION supabase_realtime ADD TABLE public.queues;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Function: Get next token number for a shop
CREATE OR REPLACE FUNCTION get_next_token_number(p_shop_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_next_token INTEGER;
BEGIN
  UPDATE public.queues
  SET last_token_number = last_token_number + 1,
      total_waiting = total_waiting + 1,
      updated_at = NOW()
  WHERE shop_id = p_shop_id
  RETURNING last_token_number INTO v_next_token;
  
  RETURN v_next_token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Advance queue (admin calls next)
CREATE OR REPLACE FUNCTION advance_queue(p_shop_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_current INTEGER;
  v_token_id UUID;
BEGIN
  -- Get current serving token
  SELECT current_token INTO v_current FROM public.queues WHERE shop_id = p_shop_id;
  
  -- Mark current as completed
  UPDATE public.tokens
  SET status = 'completed',
      completed_at = NOW(),
      actual_wait_minutes = EXTRACT(EPOCH FROM (NOW() - created_at))/60
  WHERE shop_id = p_shop_id 
    AND token_number = v_current 
    AND status = 'serving';
  
  -- Move to next token
  UPDATE public.queues
  SET current_token = current_token + 1,
      total_waiting = GREATEST(0, total_waiting - 1),
      updated_at = NOW()
  WHERE shop_id = p_shop_id
  RETURNING current_token INTO v_current;
  
  -- Mark next token as 'called'
  UPDATE public.tokens
  SET status = 'called'
  WHERE shop_id = p_shop_id 
    AND token_number = v_current 
    AND status = 'waiting';
  
  RETURN v_current;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Calculate estimated wait time
CREATE OR REPLACE FUNCTION calculate_wait_time(p_shop_id UUID, p_token_number INTEGER)
RETURNS INTEGER AS $$
DECLARE
  v_current_token INTEGER;
  v_avg_time DECIMAL;
  v_position INTEGER;
BEGIN
  SELECT current_token, avg_service_time 
  INTO v_current_token, v_avg_time
  FROM public.queues WHERE shop_id = p_shop_id;
  
  v_position := p_token_number - v_current_token;
  
  RETURN GREATEST(0, ROUND(v_position * v_avg_time));
END;
$$ LANGUAGE plpgsql;

-- Function: Update analytics daily
CREATE OR REPLACE FUNCTION update_daily_analytics()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.analytics (shop_id, date, total_customers)
  VALUES (NEW.shop_id, CURRENT_DATE, 1)
  ON CONFLICT (shop_id, date) DO UPDATE
  SET total_customers = analytics.total_customers + 1;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_analytics
AFTER INSERT ON public.tokens
FOR EACH ROW EXECUTE FUNCTION update_daily_analytics();

-- Function: Award gamification points
CREATE OR REPLACE FUNCTION award_points(p_user_id UUID, p_points INTEGER, p_badge TEXT DEFAULT NULL)
RETURNS VOID AS $$
BEGIN
  UPDATE public.users 
  SET points = points + p_points,
      on_time_arrivals = on_time_arrivals + 1
  WHERE id = p_user_id;
  
  IF p_badge IS NOT NULL THEN
    UPDATE public.users 
    SET badges = array_append(badges, p_badge)
    WHERE id = p_user_id AND NOT (p_badge = ANY(badges));
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;